/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\ScopeGuard.ahk
#include %A_LineFile%\..\OrderedDestructor.ahk
#include %A_LineFile%\..\StaticClassBase.ahk

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk


class HotUtils extends StaticClassBase
{
;public:
	static NullFunctor := ObjBindMethod({}, {})

	/**
	 * Converts AHK hotkey into human readable representation
	 *
	 * @code{.ahk}
	   ;Displays "AltGr-RAlt-LCtrl-LShift-RWin-LWin-NumpadClear"
	   MsgBox % HotUtils.hotkeyToDisplayString("~<^>!>!*<^<+>#<#sc059")
	 * @endcode
	 *
	 * @param   hotkeyEncoded  The hotkey encoded according to AutoHotkey rules
	 * @param   joiner         The string which joins individual keys in the resulting value
	 *
	 * @return  Human readable representation of AHK-encoded hotkey
	 */
	hotkeyToDisplayString(hotkeyEncoded, joiner := "-") {
		cAltGrModifierName := "AltGr"
		cModifiers := { "^"    : "Ctrl"
		              , "!"    : "Alt"
		              , "+"    : "Shift"
		              , "#"    : "Win" }
		cModifiersPlacement := { "<" : "L"
		                       , ">" : "R" }

		if (!HotkeyExist(hotkeyEncoded)) {
			Hotkey(hotkeyEncoded, HotUtils.NullFunctor) ;Throws exception in case of invalid hotkey
			Hotkey(hotkeyEncoded, HotUtils.NullFunctor, "OFF", true) ;Disable hotkey if it was successfully validated and registered on previos line
		}

		he := hotkeyEncoded
		he := this.clearHotkeyFromSpecialSymbols(he)

		; Uppercase single-letter keys, i.e. "^p" becomes "^P", but "^PgDn" will be untouched
		pos := 1
		while (RegexMatch(he, "O)\b\w\b", m, pos)) {
			needle := SubStr(he, m.Pos, 1)
			he := StrReplace(he, needle, Format("{:U}", needle))
			pos += 1
		}

		if (RegExMatch(he, "iO)(.+)\s+&\s+(.+)", m)) {
			;"Custom combinations" hotkey with "&" cannot have special modifiers, so skip
			;all those transformations and just join 2 parts, possibly converting scan/virtual codes.
			return HotUtils.tryConvertScVcToKeyName(m[1]) . joiner . HotUtils.tryConvertScVcToKeyName(m[2])
		}

		;Firstly check AltGr modifier manually because it intersects with other modifiers ("<^" and ">!")
		he := StrReplace(he, "<^>!", cAltGrModifierName)
		for k, v in cModifiers {
			he := StrReplace(he, k, v)
		}

		possibleModifierPlacements := ""
		for k, v in cModifiersPlacement {
			he := StrReplace(he, k, v)
			possibleModifierPlacements .= v
		}
		hotkeyPartsSplitRegex := "[" possibleModifierPlacements "]?("

		hotkeyPartsSplitRegex .= cAltGrModifierName "|"
		for k, v in cModifiers {
			hotkeyPartsSplitRegex .= v
			hotkeyPartsSplitRegex .= (A_Index = cModifiers.Count() ? "" : "|")
		}
		hotkeyPartsSplitRegex .= "|" HotUtils.cVkScPattern
		hotkeyPartsSplitRegex .= "|\w+)" ;literal key name. Should be the last among regex subpatterns

		hotkeyParts := []
		pos := 1
		while (RegExMatch(he, "iO)" hotkeyPartsSplitRegex, m, pos)) {
			hotkeyParts.Push(SubStr(he, m.Pos, m.Len))
			pos += m.Len
		}
		if (tail := SubStr(he, pos)) {
			hotkeyParts.Push(tail)
		}

		finalString := ""
		for i, v in hotkeyParts {
			finalString .= HotUtils.tryConvertScVcToKeyName(v, "iO)" HotUtils.cVkScPattern)
			             . (A_Index = hotkeyParts.Length() ? "" : joiner)
		}
		return finalString
	}

;private:
	static cVkScPattern := "(sc[0-9a-f]+)|(vk([0-9a-f])+)"

	tryConvertScVcToKeyName(hotkeyString) {
		return RegExMatch(hotkeyString, "iO)" HotUtils.cVkScPattern, m) ? StrReplace(hotkeyString, m[0], GetKeyName(m[0]))
		                                                                : hotkeyString
	}
	clearHotkeyFromSpecialSymbols(hotkeyString) {
		return RegexReplace(hotkeyString, "i)([\*~\$])|(\s+up\s*)") ;f.e. "~*^t up" becomes "^t"
	}
}

/**
 * Check hotstring for existence in current script
 *
 * @param   hs  Hotstring with usual syntax expected by @c Hotstring builtin function
 *
 * @return  @c false if @p hs does not exist or it has no variant for the current IfWin criteria;
 *          @c true otherwise
 */
HotstringExist(hs) {
	try Hotstring(hs)
	catch
		return false
	return true
}

/**
 * Get hotstring trigger cleaned up from options
 *
 * @code{.ahk}
 *
   ;prints "test" or "quest" depending on executed hotstring
   :*x?C:test::
   :*x?C:quest::MsgBox % hotstringTrigger()
 *
 * @endcode
 *
 * @param   hs  Hotstring label. Defaults to A_ThisHotkey if omitted
 *
 * @return  Hostring's trigger cleaned up from options
 */
hotstringTrigger(hs := "") {
	return RegexReplace(hs ? hs : A_ThisHotkey, ":.*?:(.+)$", "$1")
}

/**
 * Temporary alter `Hotkey If` condition for subsequent hotkeys
 *
 * This is complementary function to @ref HotkeyIf() — it returns @ref ScopeGuard object which
 * restores previously active `Hotkey If` condition for hotkeys upon destruction i.e. upon return
 * from currently executing function.
 * This function is for complex usage scenarios where context-sensitive hotkeys are created
 * dynamically inside deeply nested call stacks of functions
 *
 * @param   newFunctor  The new functor for `Hotkey If` condition. It will be active until returned
 *                      @ref ScopeGuard object is valid
 *
 * @return  @ref ScopeGuard object instance which restores previously active HotkeyIf criteria upon
 *          destruction
 */
scopedHotkeyIf(newFunctor := "") {
	return new ScopeGuard(Func("HotkeyIf").Bind(prevFunctor := HotkeyIf(newFunctor)))
}

/**
 * Create temporary hotkey(s) in current function scope.
 *
 * The hotkey will be deleted when the handle returned by this function go out of scope or there are
 * zero references to it.
 *
 * First 3 parameters are identical to `Hotkey` builtin command, except @p KeyName, which also can be an array of
 * objects with keys `k`, `f`, `o` — `key`, `func, `options` respectively. By passing such an object, multiple temporary
 * hotkeys can be registered; @p Label and @p Options are ignored in this case and @p hotkeyIfFunctor is shared for all
 * hotkeys.
 * of hotkeys. The 4th parameter, @p hotkeyIfFunctor, is the
 *
 * @param   KeyName              Key name/hotkey trigger. Can also be an array of hotkeys, see function description
 *                               for details
 * @param   Label                Label/function/functor to bind to @p KeyName
 * @param   Options              Hotkey options
 * @param   hotkeyIfFunctor      The HotkeIf functor/function to enable context sensitivity for hotkeys in @p KeyName
 *
 * @return  RAII handle for newly created hotkey(s)
 */
scopedHotkey(KeyName, Label := "", Options := "", hotkeyIfFunctor := "") {
	triggers := IsObject(KeyName) ? KeyName : [{k: KeyName, f: Label, o: Options}]

	handles := []
	if (hotkeyIfFunctor) {
		handles.Push(guardRestoreContextForHotkey := scopedHotkeyIf(hotkeyIfFunctor))
	}

	for i, v in triggers  {
		Hotkey(v.k, v.f, v.o)
		handles.Push(guardDisableHotkey := new ScopeGuard(Func("Hotkey").Bind(v.k, v.f, "OFF", true)))
	}
	return new OrderedDestructor(handles, true)
}

/**
 * Bind functions to be executed on single-/double-/triple-/N-press of hotkey
 *
 * Function accepts Func/BoundFunc objects or literal names in @p pressHandlers
 * parameter. It can be {key: value} object or [linear array]. Object is
 * recommended way because it is more illustrative and compact (doesn't require to specify empty
 * parameter for each number of key presses you want to omit from handling).
 * The next 2 examples are equivalent:
 *
 * Object example:
 *    { 2: "function_double_press"
 *    , 3: "function_triple_press"
 *    , 6: "function_6_presses" }
 *
 * Linear array example:
 *    ["", "function_double_press", "function_triple_press", "", "", "function_6_presses"]
 * The index @c I inside this array determines the count of hotkey presses required to
 * execute @c I-th handler. Specify empty value in parameter number @c X to skip handling of @c X-th
 * press of the hotkey.
 *
 * @code{.ahk}
   ;Try press Ctrl+T from 1 to 6 times.
   ^t::OutputDebug % "Handler's return value: "
              . HandleMultiPressHotkey({2: "MyMsgBox" ;2-press. result: ""
       , 3: _F("MyMsgBox", 3)        ;3-press. result: 8
       , 4: _F("Run", "notepad.exe") ;4-press: launch Notepad. result: process ID (PID) of newly launched notepad instance
                                     ;5-press: skip  intentionally, do nothing. result: ""
       , 6: _F("ExitApp", 43)})      ;6-press: exit script with code 43

   _F(funcName, params*) {
   	return Func(funcName).Bind(params*)
   }
   MyMsgBox(pressCount := "some") {
   	MsgBox % A_ThisHotkey " hotkey pressed " pressCount " times!"
   	return pressCount + 5
   }
   ExitApp(exitCode := 0) {
   	ExitApp exitCode
   }
   Run(Target, WorkingDir := "", Mode := "") {
   	Run %Target%, %WorkingDir%, %Mode%, v
   	Return v
   }
   Send(keys) {
   	Send % keys
   }
   FSend(keys) {
   	return Func("Send").Bind(keys)
   }
 * @endcode
 *
 * @param   pressHandlers                       The functions to be executed when `A_ThisHotkey` fired. Can be Array or
 *                                              key-value object
 * @param   keyWaitDelayMax                     Maximum time in milliseconds to wait for next triggering
 *                                              of `A_ThisHotkey`. If `A_ThisHotkey` does not trigger during this
 *                                              interval, the current invocation of HandleMultiPressHotkey() is
 *                                              considered finished. The matching handler from @p pressHandlers is
 *                                              executed if any, but if @p keyWaitDelayMin is also specified, its
 *                                              conditions must be satisfied also for matching handler to be executed.
 * @param   keyWaitDelayMin                     Minimum time in milliseconds to wait for `A_ThisHotkey` trigger after
 *                                              which the `A_ThisHotkey`'s multi press counter is incremented.
 *                                              Must be less than @p keyWaitDelayMax, otherwise will throw exception.
 *                                              If `A_ThisHotkey` trigger during this interval, the current
 *                                              invocation of HandleMultiPressHotkey() is considered finished,
 *                                              executing matching handler from @p pressHandlers if any.
 * @param   preserveOriginalKeyOnEmptyHandlers  Send original hotkey trigger when there is no corresponding press
 *                                              handler exist in @p pressHandlers.
 * @param   additionalKeyWaitOptions            Additional options for `KeyWait` command which is used internally by
 *                                              this function. Note that this parameter appended to `KeyWait`'s options
 *                                              for both key up and key down modes of operation.
 *
 * @return  The return value of N-th handler from @p pressHandlers, which corresponds to @c N-th valid press
 *          (according to passed @p keyWaitDelayMin and @p keyWaitDelayMax) of `A_ThisHotkey`
 *
 * @see     https://www.autohotkey.com/boards/viewtopic.php?t=40161
 *          https://autohotkey.com/board/topic/32973-func-waitthishotkey/
 */
HandleMultiPressHotkey(pressHandlers, keyWaitDelayMax := 150, keyWaitDelayMin := 0, preserveOriginalKeyOnEmptyHandlers := true, additionalKeyWaitOptions := "") {
	if (keyWaitDelayMax <= 0) {
		Throw "Max delay should always be greater than 0"
	}
	if (keyWaitDelayMin < 0 || keyWaitDelayMin > keyWaitDelayMax) {
		Throw "Invalid keyWaitDelayMin"
	}

	strippedHotkey := RegExReplace(A_ThisHotkey, "i)(?:[~#!<>\*\+\^\$]*([^ ]+)(?: UP)?)$", "$1")
	if (preserveOriginalKeyOnEmptyHandlers && InStr(A_ThisHotkey, "joy")) {
		preserveOriginalKeyOnEmptyHandlers := false
	}

	if (preserveOriginalKeyOnEmptyHandlers && !pressHandlers.HasKey(1)) {
		Send {%strippedHotkey% down}
	}

	validKeyPresses := 1
	keyPressedBeforeMaxTimeout := false
	keyPressedAfterMinTimeout := false
	options := "DT" (keyWaitDelayMax / 1000)
	Loop {
		KeyWait, %strippedHotkey%, %additionalKeyWaitOptions%           ; Wait for KeyUp.
		if (preserveOriginalKeyOnEmptyHandlers && !pressHandlers.HasKey(A_Index)) {
			Send {%strippedHotkey% up}
		}
		startTime := A_TickCount
		; logDebug("startTime:", startTime)
		KeyWait, %strippedHotkey%, %options%%additionalKeyWaitOptions%  ; Wait for same KeyDown or timeout to elapse if specified

		keyPressedBeforeMaxTimeout := !ErrorLevel
		keyPressedAfterMinTimeout := ErrorLevel || (keyWaitDelayMin <= 0) || ((A_TickCount - startTime) >= keyWaitDelayMin)
		keyPressValid := keyPressedBeforeMaxTimeout && keyPressedAfterMinTimeout

		sendOriginalKey := preserveOriginalKeyOnEmptyHandlers && keyPressValid && !pressHandlers.HasKey(A_Index+1)
		if (sendOriginalKey) {
			Send {%strippedHotkey% down}
		}
		if (keyPressValid)
			++validKeyPresses
		else
			break
	}
	if (sendOriginalKey) {
		Send {%strippedHotkey% up}
	}
	; logDebug("validKeyPresses:", validKeyPresses)
	if (!pressHandlers.HasKey(validKeyPresses)) {
		return ""
	}

	f := pressHandlers[validKeyPresses]
	if (!IsObject(f)) { ;If not Func or BoundFunc object (i.e. just a string containing function name)
		f := Func(f)
	}
	return f ? f.Call() : "" ;Test Func object for validity/existence before calling
}

/**
 * Emulate holding key (aka autorepeat key) with optional remapping
 *
 * May be useful for video games where some action requires holding key all time. For example,
 * if in the game a key @c c need to be hold all the time to activate sneak mode, the next line
 * converts it to toggle which need to be pressed only once:
 *
 * $c::autoRepeatKey("c") ;$ required to force use of keyboard hook
 *
 * Note that @p autoRepeatInterval should be tweaked depending on how fast a target application
 * can processs keystrokes stream
 *
 * @code{.ahk}
   #UseHook ;Force use of keyboard hook for all hotkeys beneath this line

   ;Press @c x and/or @c y key to start sending it/them every 100ms. Press again to stop
   x::
   y::autoRepeatKey()

   ;Press @c q key to start sending @c b key every 50ms. Press @c q key again to stop
   q::autoRepeatKey("q", "b", 50)

   ;Modifier key (left shift)
   LShift::autoRepeatKey("LShift", "s")

   ;Joystick buttons also supported
   Joy2::
   Joy3::autoRepeatKey(A_ThisHotkey, A_ThisHotkey = "Joy2" ? "a" : "b")
 * @endcode
 *
 * @param  triggerKey          The trigger key which should be pressed once physically by user
 *                             to start autorepeating. Defaults to A_ThisHotkey if omitted or empty
 * @param  remapKey            This key will be produced every @p autoRepeatInterval milliseconds
 *                             after @p triggerKey is pressed. Press @p triggerKey again to stop
 *                             keystrokes producing. Omitting this parameter will send @p triggerKey
 *                             itself (no remapping)
 * @param  autoRepeatInterval  The automatic keystroke repeat interval in milliseconds
 *
 * @return  @c true if autorepeating active for @p triggerKey, @c false otherwise
 */
autoRepeatKey(triggerKey := "", remapKey := "", autoRepeatInterval := 100) {
	cTimeoutToReleaseTrigger := 200
	static activeTriggers := {}

	triggerKey := triggerKey ? triggerKey : A_ThisHotkey
	remapKey := remapKey ? remapKey : triggerKey
	autoRepeatInterval := Abs(autoRepeatInterval)

	if (activeTriggers.HasKey(triggerKey)) {
		SetTimer(activeTriggers.Delete(triggerKey), "Delete")
		return false
	}

	activeTriggers[triggerKey] := Func("autoRepeatKey_watchKeyUpFunc").Bind(triggerKey, remapKey)

	;Give some time to user to release trigger key. Sleep not less than 200 ms
	sleepDuration := (cTimeoutToReleaseTrigger > autoRepeatInterval) ? (cTimeoutToReleaseTrigger - autoRepeatInterval)
	               : (cTimeoutToReleaseTrigger < autoRepeatInterval) ? 0 : 0
	if (sleepDuration) {
		Sleep sleepDuration
	}
	SetTimer(activeTriggers[triggerKey], autoRepeatInterval)

	return true
} autoRepeatKey_watchKeyUpFunc(triggerKey, remapKey) {
	if (!GetKeyState(triggerKey, "P")) {
		Send {%remapKey% down}
		return
	}
	Send {%remapKey% up}
	try
		SetTimer,,Delete
	catch
		return ;Timer already deleted, nothing to do
}
