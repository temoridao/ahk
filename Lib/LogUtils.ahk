/**
 * @file
 * Helper functions for logging
 *
 * Logs are written through @c OutputDebug and optionally into text file
 * named after A_ScriptName + ".log" extension.
 *
 * @code{.ahk}
   #include <LogUtils>

   ;Uncomment line below to write log messages in the file as well
   ; LoggerConfiguration.WriteToFile := true

   logDebug("Hello, I am test message:", ["an", "array", 1, 3, 5], [{"objects" : "111"}, "supported"])
   logInfo("Hello, I am {} message", "formatted INFO", "remaining arguments are appended if no format specifier found for them")
   logWarn("Hello, I am test message")
   logCritical("Hello, I am test message")
   logFatal("Hello, I am test message")
   @endcode
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#include %A_LineFile%\..\..\3rdparty\AutoHotkey-JSON\JSON.ahk

class LoggerConfiguration {
	static WriteToFile := false
}

logDebug(logMessage := "", params*) {
	logImpl(logMessage, "D", params*)
}
logInfo(logMessage := "", params*) {
	logImpl(logMessage, "I", params*)
}
logWarn(logMessage := "", params*) {
	logImpl(logMessage, "W", params*)
}
logCritical(logMessage := "", params*) {
	logImpl(logMessage, "C", params*)
}
logFatal(logMessage := "", params*) {
	logImpl(logMessage, "F", params*)
}
logClear() {
	OutputDebug DBGVIEWCLEAR ;Special message clears DBGVIEW log window
}
logImpl(logMessage, severity, params*) {
	if (IsObject(logMessage)) { ;Allow to skip message and pass objects as first parameter
		params := [logMessage, params*]
		logMessage := ""
	}

	formattedMessage := severity " [" A_ScriptName "::" Traceback(false)[3].caller  "] "
	if (params.Length()) {
		formatSpecsCount := 0
		pos := 1
		while (RegexMatch(logMessage, "O)\{\}", m, pos)) {
			formatSpecsCount++
			pos := m.Pos + m.Len
		}

		for i, param in params {
			dumped := (IsObject(param) ? ("<" param.Count() ">") : "") . StrReplace(JSON.Dump(param,,2), "\\", "\")
			if (A_Index <= formatSpecsCount) {
				logMessage := Format(logMessage, dumped)
			} else {
				;{} format specifier not found for this variadic argument, so just append dumped argument to resulting string
				logMessage .= " " dumped
			}
		}
	}
	formattedMessage .= logMessage "`n"

	OutputDebug % formattedMessage

	FormatTime dateTime,, dd-MM-yyyy HH:mm:ss
	timestamp := dateTime "." A_MSec
	FileAppend % timestamp " " formattedMessage, *

	if (LoggerConfiguration.WriteToFile) {
		;remove first occurrence of script name, because log file already named after this script
		FileAppend, % timestamp " " StrReplace(formattedMessage, A_ScriptName, "",, 1), % A_ScriptFullPath ".log"
	}
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
Traceback(actual := false) {
	r := []
	n := actual ? 0 : A_AhkVersion < "2" ? 1 : 2
	Loop {
		e := Exception(".", offset := -(A_Index + n))
		if (e.What == offset) {
			break
		}
		r[A_Index] := { "file": e.file, "line": e.Line, "caller": e.What, "offset": offset + n }
	}

	return r
}
