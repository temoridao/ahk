/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */
#include %A_LineFile%\..\ImmutableClass.ahk

/**
 * Utitility functions to work with URLs
 */
class UrlUtil extends ImmutableClass
{
	IsConnectedToInternet() {
		return UrlUtil.UrlDownloadToVar("http://www.google.com")
	}

	UrlDownloadToVar(url) {
		ComObjError(false)
		WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		WebRequest.Open("GET", url)
		WebRequest.Send()
		Return WebRequest.ResponseText
	}

	UriEncode(Uri, RE="[0-9A-Za-z]") {
		VarSetCapacity(Var, StrPut(Uri, "UTF-8"), 0), StrPut(Uri, &Var, "UTF-8")
		Res := ""
		While Code := NumGet(Var, A_Index - 1, "UChar")
			Res .= (Chr:=Chr(Code)) ~= RE ? Chr : Format("%{:02X}", Code)
		Return, Res
	}
}