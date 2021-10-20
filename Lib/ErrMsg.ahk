/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

/**
 * Get textual description of the operating system error
 *
 * @param   errNum  The error number (A_LastError if not specified)
 *
 * @return  String with hexadecimal error number and textual representation with `r`n characters
 *          replaced by spaces
 */
ErrMsg(errNum := "") {
	if (!errNum) {
		errNum := A_LastError
	}

	VarSetCapacity(errorString, 1024) ;String to hold the error-message.
	DllCall("FormatMessage"
		, "UINT", 0x00001000     ;FORMAT_MESSAGE_FROM_SYSTEM: The function should search the system message-table resource(s) for the requested message.
		, "UINT", 0              ;A handle to the module that contains the message table to search.
		, "UINT", errNum
		, "UINT", 0              ;Language-ID is automatically retrieved
		, "STR",  errorString
		, "UINT", 1024           ;Buffer-Length
		, "STR",  "")            ;An array of values that are used as insert values in the formatted message. (not used)

	errorString := StrReplace(errorString, "`r`n", A_Space)  ;Replaces newlines by A_Space for one-line output
	return Format("({:#x}) {:s}", errNum, errorString)
}
