/*
 * Function: ErrMsg
 *     Get textual description of the operating system error
 * Parameters:
 *     ErrNum - Error number (A_LastError by default)
 * Returns:
 *     String
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
 */
ErrMsg(ErrNum := "") {
	if !ErrNum {
		ErrNum := A_LastError
	}

	VarSetCapacity(ErrorString, 1024) ;String to hold the error-message.
	DllCall("FormatMessage"
		, "UINT", 0x00001000     ;FORMAT_MESSAGE_FROM_SYSTEM: The function should search the system message-table resource(s) for the requested message.
		, "UINT", 0              ;A handle to the module that contains the message table to search.
		, "UINT", ErrNum
		, "UINT", 0              ;Language-ID is automatically retrieved
		, "STR",  ErrorString
		, "UINT", 1024           ;Buffer-Length
		, "STR",  "")            ;An array of values that are used as insert values in the formatted message. (not used)

	StringReplace, ErrorString, ErrorString, `r`n, %A_Space%, All  ;Replaces newlines by A_Space for one-line output
	return Format("({:#x}) {:s}", ErrNum, ErrorString)
}
