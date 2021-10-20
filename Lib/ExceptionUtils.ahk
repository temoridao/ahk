/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\LogUtils.ahk ;For Traceback()
#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\Funcs.ahk

/**
 * #include this class into your script (directly or indirectly) and it will automatically regiser
 * `ExceptionUtils.onErrorFunc` as @c OnError() handler which prints more useful and compact error
 * message than standard AHK handler
 *
 * The recommended way to throw expression is to call @ref throwException() function.
 *
 * Set @c ExceptionUtils.UseMessageBox static variable to @c true to print error message in message
 * box instead of tooltip.
 *
 * @note: Composed error message also copied into clipboard; use @c ExceptionUtils.StoreInClipboard
 * to change this
 *
 */

class ExceptionUtils extends StaticClassBase {
;public:
	static UseMessageBox := false
	     , StoreInClipboard := true

;private:
	static _selfRegister := OnError(ObjBindMethod(ExceptionUtils, "onErrorFunc"))

	onErrorFunc(e) {
		errorText := "Exception thrown: " e
		if (IsObject(e)) {
			errorText := e.File
			           . "`n--------------------------`n"
			           . "Exception in " quote(e.What) " on line " e.Line ": " e.Message "`n`n"
			           . "Extra: " e.Extra
		}

		if (ExceptionUtils.UseMessageBox) {
			MsgBox % errorText
		} else {
			ToolTip % errorText
			SetTimer("ToolTip", -5000)
		}

		if (ExceptionUtils.StoreInClipboard) {
			Clipboard := errorText
		}

		return true ;Block standard message box display
	}
}
