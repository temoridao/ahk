/**
 * @file
 * Contains basic utility functions primarily enhancing standard AutoHotkey functions/commands
 *
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

/**
 * Get value bounded between minimum and maximum
 *
 * Throws an exception if @p min > @p max
 *
 * @param   v    The value
 * @param   min  The minimum
 * @param   max  The maximum
 *
 * @return  If @p v compares less than @p min, returns @p min; otherwise if @p max compares less
 *          than @p v, returns @p max; otherwise returns @p v
 */
Clamp(v, min, max) {
	if (min > max) {
		Throw "Invalid parameters: min > max"
	}

	return v < min ? min
	     : v > max ? max
	     : v
}

/**
 * Check if object has value (complement for built-in HasKey() method)
 *
 * @code{.ahk}
   MsgBox % HasVal(["orange", "banana", "apple"], "banana") ; Outputs "2"
 * @endcode
 *
 * @param   obj     The object to check value presence in
 * @param   needle  The needle value
 *
 * @return  First key in @p obj which has value equal to @p needle. 0 returned if nothing found
 */
HasVal(ByRef obj, ByRef needle) {
	for index, value in obj {
		if (value = needle) {
			Return index
		}
	}

	Return 0
}

/**
 * Removes a value from linear array
 *
 * @param   linearArrayObj  The linear array object from which a value will be removed
 * @param   val             The value to be removed from array (if found)
 *
 * @return  @c true if the first occurrence of @p val was removed, @c false otherwise
 */
RemoveVal(ByRef linearArrayObj, ByRef val) {
	if (pos := HasVal(linearArrayObj, val)) {
		linearArrayObj.RemoveAt(pos)
		return true
	}

	return false
}

RunAsAdmin(Target, WorkingDir := "", Mode := "") {
	Run *RunAs %Target%, %WorkingDir%, %Mode%, v
	return v
}

/**
 * Resolve absolute path from relative
 *
 * @param   path  The path, possibly relative or with ".."
 *
 * @return  The absolute path resolved from @p path
 */
GetFullPathName(path) {
	cc := DllCall("GetFullPathName", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
	VarSetCapacity(buf, cc * (A_IsUnicode ? 2: 1))
	DllCall("GetFullPathName", "str", path, "uint", cc, "str", buf, "ptr", 0, "uint")
	return buf
}

/**
 * Sort array object
 *
 * @param   arr      The array object
 * @param   options  Sorting options similar to builit-in 'Sort' command
 *
 * @return  Sorted copy of @p arr according to @p options, or empty array if error occurs
 */
sortArray(arr, options:="") {
	if (!IsObject(arr)) {
		throw "Object expected"
	}

	list := ""
	for i, item in arr {
		list .= item "`n"
	}

	list := Trim(list, "`n")
	Sort list, %options%

	result := []
	Loop Parse, list, `n
		result.Push(A_LoopField)
	return result
}

SplashImageOff() {
	SplashImage OFF
}

/**
 * Gets the command line positional parameter's value
 *
 * @param   parameterName  The parameter name
 * @param   defaultValue   The default value
 *
 * @return  The command line value next to @p parameterName or @p defaultValue if not found
 */
GetCmdParameterValue(parameterName, defaultValue := "") {
	value := defaultValue
	if (i := HasVal(A_Args, parameterName)) {
		if (A_Args.Length() > i) {
			value := A_Args[i+1]
		}
	}
	return value
}

FSend(keys) {
	return Func("Send").Bind(keys)
}
_F(funcName, params*) {
	return Func(funcName).Bind(params*)
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
   ^t::MsgBox % "Handler's return value: "
              . HandleMultiPressHotkey({1: FSend("^t") ;Single-press: retain original hotkey action (Ctrl+T)
       , 2: "MyMsgBox"               ;2-press. result: ""
       , 3: _F("MyMsgBox", 3)        ;3-press. result: 8
       , 4: _F("Run", "notepad.exe") ;4-press: launch Notepad. result: process ID (PID) of newly launched notepad instance
                                     ;5-press: skip  intentionally, do nothing. result: ""
       , 6: _F("ExitApp", 43)})      ;6-press: exit script with code 43
       ;, 150: _F("MyMsgBox", "Can you do this?!")}) ;150-press: Can you complete this? :)

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
 * @param   pressHandlers  The functions to be executed when @c A_ThisHotkey fired. Can be Array or
 *                         key-value object
 * @param   keyWaitDelay   Maximum time in milliseconds to wait for next triggering of hotkey
 *
 * @return  The return value of Nth handler from @p pressHandlers, which corresponds to @c N presses
 *          of @c A_ThisHotkey
 *
 * @see     https://www.autohotkey.com/boards/viewtopic.php?t=40161
 *          https://autohotkey.com/board/topic/32973-func-waitthishotkey/
 */
HandleMultiPressHotkey(pressHandlers, keyWaitDelay := 150) {
	strippedHotkey := RegExReplace(A_ThisHotkey, "i)(?:[~#!<>\*\+\^\$]*([^ ]+)(?: UP)?)$", "$1")
	keyPresses := 0
	keyPressedBeforeTimeout := false
	options := "DT" keyWaitDelay / 1000
	Loop {
		++keyPresses
		KeyWait, %strippedHotkey%            ; Wait for KeyUp.
		KeyWait, %strippedHotkey%, %options% ; Wait for same KeyDown or `keyWaitDelay` to elapse.
		keyPressedBeforeTimeout := (ErrorLevel = 0)
	} Until !keyPressedBeforeTimeout

	if (!pressHandlers.HasKey(keyPresses)) {
		return ""
	}

	f := pressHandlers[keyPresses]
	if (!IsObject(f)) { ;If not Func or BoundFunc object (i.e. just a string containing function name)
		f := Func(f)
	}
	return f ? f.Call() : "" ;Test Func object for validity/existence before calling
}

callFuncFromScriptArgs() {
	if (A_Args.Length() = 0) {
		MsgBox % "[" A_ThisFunc "] No cmd arguments, so no function to call"
		ErrorLevel := "No Args"
		return 0
	}

	if (!IsFunc(A_Args[1])) {
		MsgBox 0x10,, % "Requested function " quote(A_Args[1]) " doesn't exist"
		ExitApp 1
	}
	funcArguments := A_Args.Clone(), funcArguments.RemoveAt(1)
	; OutputDebug % "[" A_ThisFunc "] Calling function " quote(A_Args[1])
	ErrorLevel := ""
	return A_Args[1](funcArguments*)
}

/**
 * Put computer to specified suspend state
 *
 * Allows to put computer to sleep or hibernate which is not possible with built-in \c Shutdown
 * command
 *
 * @param   mode  Possible values: "sleep", "hibernate"
 *
 * @return  @c true on success, @c false otherwise
 */
setComputerSuspendState(mode := "Sleep") {
	doHibernate := false
	if (mode = "Sleep") {
		doHibernate := false
	} else if (mode = "hibernate") {
		doHibernate := true
	} else {
		return false
	}

	return DllCall("PowrProf\SetSuspendState"
		           , "int", doHibernate
		           , "int", 0
		           , "int", 0)
}

quote(ByRef text, _q_ := """") {
	return _q_ text _q_
}

;Convenience wrappers for Sleep command's duration parameter. Return specified duration in milliseconds.
seconds(count := 1) {
	return count * 1000
}
minutes(count := 1) {
	return count * seconds(60)
}
hours(count := 1) {
	return count * minutes(60)
}
days(count := 1) {
	return count * hours(24)
}

/**
 * Convert the specified number of seconds to hh:mm:ss format
 *
 * @param   NumberOfSeconds  The number of seconds
 *
 * @return  @p NumberOfSeconds converted to string in format hh:mm:ss
 */
FormatSeconds(NumberOfSeconds) {
	time := 19990101  ; *Midnight* of an arbitrary date.
	time += NumberOfSeconds, seconds
	FormatTime, mmss, %time%, mm:ss
	return Format("{:02d}", NumberOfSeconds // 3600) ":" mmss
	/*
	; Unlike the method used above, this would not support more than 24 hours worth of seconds:
	FormatTime, hmmss, %time%, h:mm:ss
	return hmmss
	*/
}