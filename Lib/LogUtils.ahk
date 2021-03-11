/**
 * @file
 * Helper functions for logging
 *
 * @code{.ahk}
   #include <LogUtils>

   logDebug("Hello, I am test message")
   logInfo("Hello, I am test message")
   logWarn("Hello, I am test message")
   logCritical("Hello, I am test message")
   logFatal("Hello, I am test message")
   @endcode
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/
logDebug(ByRef logMessage) {
	OutputDebug % "D [" A_ScriptName "::" Traceback(false)[2].caller  "] " logMessage
}
logInfo(ByRef logMessage) {
	OutputDebug % "I [" A_ScriptName "::" Traceback(false)[2].caller  "] " logMessage
}
logWarn(ByRef logMessage) {
	OutputDebug % "W [" A_ScriptName "::" Traceback(false)[2].caller  "] " logMessage
}
logCritical(ByRef logMessage) {
	OutputDebug % "C [" A_ScriptName "::" Traceback(false)[2].caller  "] " logMessage
}
logFatal(ByRef logMessage) {
	OutputDebug % "F [" A_ScriptName "::" Traceback(false)[2].caller  "] " logMessage
}
logClear() {
	OutputDebug DBGVIEWCLEAR ;Special message clears DBGVIEW log window
}

/**
 * Get an array of objects representing a stack trace entry
 * Each object has the following fields:
 *   offset - negative offset from the top of the call stack
 *   file   - the script file
 *   line   - the line number at which the function is called
 *   caller - function name
 *
 * @param   actual  If this is true, the actual stack trace is returned which includes
 *                  @c Traceback() itself
 *
 * @return  Array of objects representing a current stack trace entry
 */
Traceback(actual:=false) {
	r := [], i := 0, n := actual ? 0 : A_AhkVersion<"2" ? 1 : 2
	Loop
	{
		e := Exception(".", offset := -(A_Index + n))
		if (e.What == offset)
		break
		r[++i] := { "file": e.file, "line": e.Line, "caller": e.What, "offset": offset + n }
	}
	return r
}
