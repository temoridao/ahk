/**
 * Description:
 *    Helper functions for logging
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
logDebug(ByRef logMessage) {
	OutputDebug % "D [" A_ScriptName "] " logMessage
}
logInfo(ByRef logMessage) {
	OutputDebug % "I [" A_ScriptName "] " logMessage
}
logWarn(ByRef logMessage) {
	OutputDebug % "W [" A_ScriptName "] " logMessage
}
logCritical(ByRef logMessage) {
	OutputDebug % "C [" A_ScriptName "] " logMessage
}
logFatal(ByRef logMessage) {
	OutputDebug % "F [" A_ScriptName "] " logMessage
}

; logDebug("Hello, I am test message")
; logInfo("Hello, I am test message")
; logWarn("Hello, I am test message")
; logCritical("Hello, I am test message")
; logFatal("Hello, I am test message")