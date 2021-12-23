/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/
/**
 * RAII style class for temporarily change A_-variables and restore their previous values
 *
 * RAII [https://en.wikipedia.org/wiki/RAII] class for temporarily change A_-variables at
 * object construction time and restore their previous values upon destruction. Very useful for
 * library code which generally should not change A_-variables as a side effect.
 *
 * @note AVarValuesRollback recognizes additional "variables" which are not existing in AutoHotkey but convenient in
 * some cases:
 * - `A_LastFoundWndow` for "last found window" which may be changed by WinExist()/WinWait/etc built-in commands.
 *    This is a way to ensure that client code still has  its "last found window" unchanged after calling your
 *    library function for example
 * - `A_Clipboard` which can be used to save current clipboard content, optionally initialize clipboard with new value
 *    and restore saved content upon exiting current function's scope (see code examples below). NOTE: if optional
 *    new value passed to `A_Clipboard`, all content after `A_Clipboard=` till end of `aVarsString` constructor's
 *    parameter will be used as initial content of clipboard, so it is recommended to use `A_Clipboard` at the very
 *    end of `aVarsString` parameter.
 *
 * The function:
 * @code{.ahk}
   fun() {
   	;Using convenience factory function avarguard() which is shorter than `new AVarValuesRollback()`
   	guard := avarguard("A_TitleMatchMode=RegEx|A_BatchLines=44|A_LastFoundWindow|"
   	                 . "A_WinDelay=96|A_Clipboard=optional clipoard initializer")
   	if (!FileExist("some_file"))
   		return
   	FileGetSize, size, some_file
   	if (size < 1000) ;file too small, return
   		return
   	;File exists and has appropriate size, append Clipboard content and return
   	FileAppend %Clipboard%, some_file
   }
 * @endcode
 *
 * Is equivalent to:
 * @code{.ahk}
   notSoFun() {
   	prevTitleMatchMode := A_TitileMatchMode
   	prevBatchLines := A_BatchLines
   	prevLastFoundWindow := WinExist()
   	prevWinDelay := A_WinDelay
   	savedClipboard := ClipboardAll
   	Clipboard := "optional clipoard initializer"
   	ClipWait 2, 1

   	if (!FileExist("some_file")) {
   		;Restore previous values of builit-in variables
   		SetTitleMatchMode %prevTitleMatchMode%
   		SetBatchLines %prevBatchLines%
   		WinExist("ahk_id" prevLastFoundWindow)
   		SetWinDelay %prevWinDelay%
   		Clipboard := savedClipboard
   		ClipWait 2, 1
   		return
   	}
   	FileGetSize, size, some_file
   	if (size < 1000) { ;file too small, return
   		;Restore previous values of builit-in variables
   		SetTitleMatchMode %prevTitleMatchMode%
   		SetBatchLines %prevBatchLines%
   		WinExist("ahk_id" prevLastFoundWindow)
   		SetWinDelay %prevWinDelay%
   		Clipboard := savedClipboard
   		ClipWait 2, 1
   		return
   	}
   	;File exists and has appropriate size, append Clipboard content and return
   	FileAppend %Clipboard%, some_file

   	;Restore previous values of builit-in variables
   	SetTitleMatchMode %prevTitleMatchMode%
   	SetBatchLines %prevBatchLines%
   	WinExist("ahk_id" prevLastFoundWindow)
   	SetWinDelay %prevWinDelay%
   	Clipboard := savedClipboard
   	ClipWait 2, 1
   }
 * @endcode
 *
 * @warning Avoid using multiple AVarValuesRollback objects **for same A_-variable** inside the same
 *          function scope. Seems like objects' destruction order in AutoHotkey is not determined so
 *          pay attention if you use multiple RAII objects at the same time this way. In this case
 *          you need manually destroy additional AVarValuesRollback objects by assigning empty
 *          string "" to them in right time because otherwise they may leave your A_-variables at
 *          inconsistent state
 *
 * Another example:
 * @code{.ahk}
   #include <AVarValuesRollback>

   SetTitleMatchMode 3 ;Exact match
   MsgBox % "Before function call: " A_TitleMatchMode
   testFunc()
   MsgBox % "After function call: " A_TitleMatchMode

   ;--------------------------End of auto-execute section--------------------------

   testFunc() {
    ;Set new values for A_-variables while remembering their current values beforehand
    raii := new AVarValuesRollback("A_TitleMatchMode=RegEx|A_BatchLines=44|A_WinDelay=96")
    ;or alternatively: raii := avarguard("A_TitleMatchMode=RegEx|A_BatchLines=44|A_WinDelay=96")
    MsgBox % "Inside function: " A_TitleMatchMode

    MsgBox % "A_BatchLines will be restored from '" A_BatchLines "' to '" raii.StoredValue["A_BatchLines"] "' and A_TitleMatchMode from '" A_TitleMatchMode "' to '" raii.StoredValue["A_TitleMatchMode"] "' upon 'raii' object destruction"
    ;Here 'raii' object destroyed effectively restoring previous values of A_-variables which was modified at construction
   }
 * @endcode
 *
 * @todo    Add method wrappers for all supported A_-variables
 */
global g_AvarValuesRollbackClipboardBuffer := "" ;Buffer for ClipboardAll which cannot be stored into object properties and only accepts plain variables
class AVarValuesRollback {
	__New(aVarsString, delimiterCharacter := "|") {
		Loop Parse, aVarsString, %delimiterCharacter%
		{
			pos := InStr(A_LoopField, "=")
			hasNewValueToSet := pos != 0

			varName := hasNewValueToSet ? SubStr(A_LoopField, 1, pos-1) : A_LoopField ;varName contains string like "A_BatchLines"
			;Remember current value; statement '%varName%' retrieves actual value from f.e. A_BatchLines built-in variable.
			;A_LastFoundWindow is a special case and handled explicitly.
			if (varName = "A_LastFoundWindow") {
				this.m_storage[varName] := WinExist()
			} else if (varName = "A_Clipboard") {
				g_AvarValuesRollbackClipboardBuffer := ClipboardAll
				Clipboard := ""
				this.m_storage[varName] := ""
			} else {
				this.m_storage[varName] := %varName%
			}

			if (hasNewValueToSet) {
				if (varName = "A_Clipboard") {
					needle := "A_Clipboard="
					this.Clipboard(SubStr(aVarsString, InStr(aVarsString, needle) + StrLen(needle)))
					return this
				}
				newValue := SubStr(A_LoopField, pos+1) ; Assume that all after '=' is a new value for variable
				this[SubStr(varName, 3)](newValue) ; Set new value for builtin variable by dynamically calling one of our wrapper methods below (more about dynamic method calling: https://www.autohotkey.com/docs/Objects.htm#Usage_Objects)
			}
		}
	}

	__Delete() {
		for varName, varVal in this.m_storage
			if (varName = "A_Clipboard")
				this[SubStr(varName, 3)](g_AvarValuesRollbackClipboardBuffer)
			else
				this[SubStr(varName, 3)](varVal)
	}

	__Call(methodName, args*) {
		if (!IsFunc(this[methodName]))
			Throw "You're trying to remember value of 'A_" methodName "' variable, but method '" methodName
			    . "(val)' doesn't exist in class '" this.__Class
			    . "'. Please, add the missing method and try again."
	}

	StoredValue[varNameString]
	{
		get {
			return this.m_storage.HasKey(varNameString) ? this.m_storage[varNameString] : ""
		}
		set {
			; This is read-only property so set{} is empty and mandatory
		}
	}

;private:
	;Method wrappers for A_-variables which must have names identical to built-in variables without A_-prefix
	BatchLines(val) {
		; m := SubStr(A_ThisFunc, InStr(A_ThisFunc, ".")+1)
		; OutputDebug % "Set A_" m " from " A_%m% " to " val
		SetBatchLines % val
	}
	CoordModeTooltip(val) {
		CoordMode ToolTip, % val
	} CoordModePixel(val) {
		CoordMode Pixel, % val
	} CoordModeMouse(val) {
		CoordMode Mouse, % val
	} CoordModeCaret(val) {
		CoordMode Caret, % val
	} CoordModeMenu(val) {
		CoordMode Menu, % val
	}
	TitleMatchMode(val) {
		SetTitleMatchMode % val
	}
	WinDelay(val) {
		SetWinDelay % val
	}
	DetectHiddenWindows(val) {
		DetectHiddenWindows % val
	}
	SendMode(val) {
		SendMode % val
	}
	LastFoundWindow(val) {
		WinExist("ahk_id" val)
	}
	SendLevel(level) {
		SendLevel level
	}
	Clipboard(val) {
		Clipboard := ""
		Clipboard := val
		if (val)
			ClipWait 2, 1
	}

	m_storage := {}
}

/**
 * Convenience factory function for AVarValuesRollback class
 *
 * @return  New AVarValuesRollback object instance
 */
avarguard(aVarsString) {
	return new AVarValuesRollback(aVarsString)
}