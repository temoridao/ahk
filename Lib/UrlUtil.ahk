/**
 * Description:
 *    %TODO%
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#include %A_LineFile%\..\ImmutableClass.ahk

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
}