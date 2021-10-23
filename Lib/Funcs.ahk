/**
 * @file
 * Contains basic utility functions primarily enhancing standard AutoHotkey functions/commands
 *
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk
#include %A_LineFile%\..\ErrMsg.ahk
#include %A_LineFile%\..\LogUtils.ahk

#include %A_LineFile%\..\..\3rdparty\AutoHotkey-JSON\JSON.ahk

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
	for key, value in obj {
		if (value = needle) {
			Return key
		}
	}

	Return 0
}

/**
 * Get Value associated with key @p needle or Key associated with value @p needle whichever comes first in @p obj
 *
 * @param   obj     The object
 * @param   needle  The needle
 */
valueOrKey(ByRef obj, ByRef needle) {
	return obj.HasKey(needle) ? obj[needle] : HasVal(obj, needle)
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
 * Execute command and get its stdout
 *
 * @param   command  The command
 *
 * @return  Stdout of @p command
 */
RunWaitOne(command) {
	shell := ComObjCreate("WScript.Shell")
	exec := shell.Exec(command)
	return exec.StdOut.ReadAll()
}

/**
 * Resolve absolute path from relative according to A_WorkingDir
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
 * Get base filename of this script
 *
 * @return  @c `A_ScriptName` without extension. For example returns "Starter" if `A_ScriptName`
 *          equals to "Starter.ahk"
 */
scriptBaseName() {
	SplitPath A_ScriptName,,,,OutNameNoExt
	return OutNameNoExt
}

scriptMsgBoxWinTitle() {
	Process Exist
	return "ahk_class #32770 ahk_pid " . ErrorLevel
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
FSendEx(keys) {
	return Func("SendEx").Bind(keys)
}
_F(funcName, params*) {
	return Func(funcName).Bind(params*)
}

/**
 * Send Extended
 *
 * Equivalent to builtin `Send` command, but allows additional embedded directives:
 *
 * - Sleep: `{SL N}`, where N is a number of milliseconds to wait before sending next portion of
 *   keys; may be prefixed with `-` sign due `Sleep` command supports -1 delay.
 *
 * - Key Delay: `{KD N}`, where N is equivalent to first parameter of builtin `SetKeyDelay` command.
 *   May be prefixed with `-` sign. Omit N to restore value of `A_KeyDelay` as it was before
 *   calling SendEx. `A_KeyDelay` value restored when this function returns.
 *
 * - Key press duration: `{KP N}`, where N is equivalent to second parameter of builtin
 *   `SetKeyDelay` command. May be prefixed with `-` sign. Omit N to restore value of
 *   `A_KeyDuration` as it was before calling SendEx. `A_KeyDuration` value restored when this
 *   function returns.
 *
 *  - Text/Raw mode: `{Text mode}` or `{Raw mode}` where `mode` either On or Off. Allow to enable/disable `Send {Text}`
 *    or `Send {Raw}` mode in the middle of the string without need to issue separate `Send` command.
 *    Omitting `mode` enables standard behaviour: all characters (including SendEx's directives) up to end of string
 *    will be interpreted literally according to documentation of corresponding Text or Rwaw mode of `Send` command.
 *
 * @note {KD} and {KP} is not obeyed by SendInput; there is no delay between keystrokes in that mode.
 * @note All directives are case insensitive
 *
 * @code
   ;prints `123` with 1 second delay after each character
   F5::SendEx("{sl 1000}1{sl 1000}2{sl 1000}3")

   ;prints `aaaaa{b 5}aaaHello`
   F6::SendEx("{kd 500}{a 5}{Text ON}{b 5}{Text off}{a 3}{kD}Hello")
 * @endcode
 *
 * @param   keys  The keys to send. Equivalent to builtin `Send` command parameter, but allows additional embedded
 *                directives
 *
 */
SendEx(ByRef keys) {
	initialKeyDelay := A_KeyDelay
	initialKeyDuration := A_KeyDuration

	static cDirectivesRegex := "iOS)"
	  .      "\{SL ?(?P<sleepDuration>-?\d+)\}"
	  . "|"  "\{KD ?(?P<keyDelay>-?\d*)\}"
	  . "|"  "\{KP ?(?P<keyDuration>-?\d*)\}"
	  . "|"  "\{(?P<textMode>Text|Raw)\s*(?P<textModeToggle>(ON|OFF)?)\}"

	textMode := ""
	pos := 1
	while (RegExMatch(keys, cDirectivesRegex, m, pos)) {
		textChunk := SubStr(keys, pos, m.pos() - pos)
		pos := m.pos() + m.len()
		if (textChunk)
			Send % textMode . textChunk

		if (m.Pos("sleepDuration") && ((sd:=m.value("sleepDuration")) >= -1)) {
			Sleep sd
		} else if (m.Pos("keyDelay")) {
			SetKeyDelay, % (v := m.value("keyDelay")) ? v : initialKeyDelay
		} else if (m.Pos("textMode")) {
			v := m.value("textModeToggle")
			textMode := v = "ON" ? ("{" m.value("textMode") "}") : ""
			if (!v)
				Goto SendExFinalize
		} else if (m.Pos("keyDuration")) {
			SetKeyDelay,, % (v := m.value("keyDuration")) ? v : initialKeyDuration
		}
	}

	SendExFinalize:
	if (textLastChunk := SubStr(keys, pos)) {
		Send % textMode . textLastChunk
	}
	SetKeyDelay, %initialKeyDelay%, %initialKeyDuration%
	return
}

ProcessExist(pidOrName := "") {
	Process Exist, % pidOrName
	return ErrorLevel
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
 * Combine Functions - combines any number of Func/BoundFunc objects into single BoundFunc object
 *
 * @code{.ahk}
   #include <CommonUtils>

   fun := "fun"
   combinedFuncs := cf("fun1", Func(fun "2"), Func("fun3").Bind("Hello"))
   Hotkey F12, % combinedFuncs
   MsgBox Press F12 to trigger hotkey.`n It will call all combined functions in order

   fun1() {
   	MsgBox %A_ThisFunc%
   }
   fun2() {
   	MsgBox %A_ThisFunc%
   }
   fun3(param) {
   	MsgBox %A_ThisFunc%: %param%
   }
 * @endcode
 *
 * @param   funcs  Variadic number of Func, BoundFunc objects or function names in any combination
 *
 * @return  BoundFunc object which combines all functions passed in @p funcs
 */
cf(funcs*) {
	return Func("runCallbackList").Bind([funcs*])
}

runCallbackList(ByRef list) {
	for each, callback in list {
		if IsObject(callback) {
			callback.Call()
		} else if (f := Func(callback)) {
			f.Call()
		}
	}
}

/**
 * Put computer to specified suspend state
 *
 * Allows to put computer to sleep or hibernate which is not possible with built-in @c Shutdown
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

/**
 * Wrapper for builtin `Shutdown` command. But unlike builtin it accepts string and optional boolean
 * instead of raw numbers to denote required action.
 *
 * @param   action  The shutdown action
 * @param   force   Perform forced @p action
 */
Shutdown(action, force := false) {
	arg := -1
	if (action = "logoff") {
		arg := 0
	} else if (action = "shutdown") {
		arg := 1
	} else if (action = "reboot") {
		arg := 2
	} else if (action = "power down") {
		arg := 8
	}

	if (arg >= 0) {
		Shutdown arg + (force ? 4 : 0)
	}
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

ObjToString(obj) {
	if (!IsObject(obj)) {
		throwException("Object expected")
	}
	return "<" obj.Count() ">" . StrReplace(JSON.Dump(obj,,2), "\\", "\")
}

ObjUniqueValues(ByRef obj) {
	hashTable := {}
	for i, v in obj
		hashTable[v] := ""
	return ObjKeys(hashTable)
}
ObjKeys(ByRef obj) {
	result := []
	for k in obj
		result.Push(k)
	return result
}
ObjValues(ByRef obj) {
	result := []
	for k, v in obj
		result.Push(v)
	return result
}

/**
 * Throw exception with a lot of useful information including stack trace and `A_LastError`
 * converted to human-readable string representation
 *
 * @note This function is most useful together with @ref ExceptionUtils class. See that class
 * documentation for details.
 *
 * @param   msg  User error message
 */
throwException(msg) {
	tb := Traceback()
	throw {File: tb[2].file
		   , What: tb[2].caller
		   , Line: tb[1].line
		   , Message: msg
		   , Extra: "GetLastError(): " ErrMsg() "`nStacktrace (most recent at the top): " StrReplace(JSON.Dump(tb,,2), "\\", "\") }
}

/**
 * Generate string with random characters
 *
 * @param   length  The length of the resulting string
 */
randomString(length) {
	Static chars := "0123456789abcdefghijklmnopqrstuvwxyz", charCount := StrLen(chars)

	result := ""
	Loop % length {
		Random, R, 1, charCount
		result .= SubStr(chars, R, 1)
	}

	return result
}

/**
 * Creates a temporary file
 *
 * @param   prefix     The prefix of the created file (`A_ScriptName` if omitted)
 * @param   extension  The extension of the created file
 * @param   directory  The directory of the created file (`A_Temp` if omitted)
 *
 * @return  Absolute path to newly created empty temporary file
 */
createTemporaryFile(prefix := "", extension := "", directory := "") {
	Loop {
		fileName := (directory ? directory : A_Temp) "\"
		          . (prefix ? prefix : A_ScriptName) "_"
		          . randomString(10)
		          . (extension ? "." extension : "")

		if (!FileExist(fileName)) {
			FileAppend("", fileName) ;create file
			if (ErrorLevel) {
				throwException("Cannot create temporary file: " quote(fileName))
			}
			return fileName
		}
	}
}

WinMinimized(winTitle := "") {
	return WinGet("MinMax", winTitle) = 1
}

t_char() {
	return A_IsUnicode ? "UShort" : "Char"
}
t_size(char_count := 1) {
	return A_IsUnicode ? char_count*2 : char_count
}
strAlloc(charactersCount, initialValue := "") {
	grantedCapacity := VarSetCapacity(str, t_size(charactersCount))
	if (initialValue) {
		len := StrLen(initialValue)
		if (len > charactersCount) {
			throwException("Initial value is larger than requested allocation size")
		}
		requiredCapacity := len * (A_IsUnicode ? 2 : 1)
		if (requiredCapacity > grantedCapacity) {
			throwException(Format("Not enough capacity granted for initial value: {}. Required: {}", grantedCapacity, requiredCapacity))
		}
		StrPut(initialValue, &str, grantedCapacity)
	}

	return str
}
