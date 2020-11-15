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
 * Bind functions to be executed on single-/double-/tripple-/N-press of hotkey (A_ThisHotkey)
 *
 * Function accepts an array of function names, Func/BoundFunc objects in its @p pressHandlers
 * parameter. The index @c I inside this array determines the count of hotkey presses required to
 * execute @c I-th handler. Specify empty value in parameter number @c X to skip handling of @c X-th
 * press of the hotkey.
 *
 * @code{.ahk}
   ;Try press Ctrl+T from 1 to 6 times
   ^t::result := HandleMultiplePresses([FSend("^t") ;1-press: retain original hotkey action. result: ""
       , _F("MyMsgBox", 2)          ;2-press. result: 7
       , _F("MyMsgBox", 3)          ;3-press. result: 8
       , _F("Run", "notepad.exe")   ;4-press: launch Notepad. result: process ID (PID) of
                                    ;         newly launched notepad instance
       , ""                         ;5-press: skip, do nothing. result: ""
       , _F("ExitApp", 43)])        ;6-press: exit script with code 43

   _F(funcName, params*) {
   	return Func(funcName).Bind(params*)
   }
   MyMsgBox(param) {
   	MsgBox % A_ThisHotkey " hotkey pressed " param " times!"
   	return param + 5
   }
   ExitApp(exitCode := 0) {
   	ExitApp exitCode
   }
   Run(Target, WorkingDir := "", Mode := "") {
   	Run %Target%, %WorkingDir%, %Mode%, v
   	Return v
   }
   FSend(keys) {
   	return Func("Send").Bind(keys)
   }
 * @endcode
 *
 * @param   pressHandlers  The array of functions to be executed when @c A_ThisHotkey fired
 * @param   keyWaitDelay   Time in milliseconds to wait between hotkey presses. 150 by default.
 *
 * @return  The result of @c I-th handler for @c I presses of @c A_ThisHotkey
 *
 * @see     https://www.autohotkey.com/boards/viewtopic.php?t=40161
 *          https://autohotkey.com/board/topic/32973-func-waitthishotkey/
 */
HandleMultiplePresses(pressHandlers, keyWaitDelay := 150) {
	strippedHotkey := RegExReplace(A_ThisHotkey, "i)(?:[~#!<>\*\+\^\$]*([^ ]+)(?: UP)?)$", "$1")
	; hotkeyType := InStr(A_ThisHotkey, " UP") ? "UP" : "DOWN"
	keyPresses := 0
	keyPressedBeforeTimeout := false
	options := "DT" keyWaitDelay / 1000
	Loop {
		++keyPresses
		KeyWait, %strippedHotkey%            ; Wait for KeyUp.
		KeyWait, %strippedHotkey%, %options% ; Wait for same KeyDown or .12 seconds to elapse.
		keyPressedBeforeTimeout := (ErrorLevel = 0)
	} Until !keyPressedBeforeTimeout

	if (keyPresses > pressHandlers.Length()) {
		return ""
	}

	f := pressHandlers[keyPresses]
	if (!IsObject(f)) { ;If not Func or BoundFunc object (i.e. just a string containing function name)
		f := Func(f)
	}
	return f ? f.Call() : ""
}