/**
 * Description:
 *    RAII [https://en.wikipedia.org/wiki/RAII] class for temporarily change A_-variables at object
 *    construction time and restore their previous values upon destruction. Very useful for libray code
 *    which generally should not change A_-variables as a side effect.
 *
 *    This line:
 *    	raii := new AVarValuesRollback("A_TitleMatchMode=RegEx|A_BatchLines=44|A_WinDelay=96")
 *    Is equivalent to:
 *    	prevTitleMatchMode := A_TitileMatchMode
 *    	prevBatchLines := A_BatchLines
 *    	prevWinDelay := A_WinDelay
 *    	;...
 *    	SetTitleMatchMode %prevTitleMatchMode%
 *    	SetBatchLines %prevBatchLines%
 *    	SetWinDelay %prevWinDelay%
 *
 *    NOTE: avoid using mutliple AVarValuesRollback objects inside one function.
 *    Seems like objects' destruction order in AutoHotkey is not determined so pay attention
 *    if you use multiple RAII objects at the same time. In this case you need manually destroy additional
 *    AVarValuesRollback objects by assigning empty string "" to them in right time because otherwise
 *    they may leave your A_-variables at inconsistent state.
 * Usage:
 *    SetTitleMatchMode 3 ; Exact match
 *    MsgBox % "Before function call: " A_TitleMatchMode
 *    testFunc()
 *    MsgBox % "After function call: " A_TitleMatchMode
 *
 *    ;----------------End of Auto-Execute section----------------
 *    testFunc() {
 *    	raii := new AVarValuesRollback("A_TitleMatchMode=RegEx|A_BatchLines=44|A_WinDelay=96") ; Set new values for A_-variables while remembering their current values beforehand:
 *    	Msgbox % "Inside function: " A_TitleMatchMode
 *
 *    	Msgbox % "A_BatchLines will be restored from '" A_BatchLines "' to '" raii.StoredValue["A_BatchLines"] "' and A_TitleMatchMode from '" A_TitleMatchMode "' to '" raii.StoredValue["A_TitleMatchMode"] "' upon 'raii' object destruction"
 *    	; Here 'raii' object destroyed effectively restoring previous values of A_-variables which was modified at construction
 *    }
 *
 * TODO:
 *    Add method wrappers for all supported A_-variables
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
class AVarValuesRollback {
	__New(aVarsString, delimiterCharacter := "|") {
		Loop Parse, aVarsString, %delimiterCharacter%
		{
			pos := InStr(A_LoopField, "=")
			hasNewValueToSet := pos != 0

			varName := hasNewValueToSet ? SubStr(A_LoopField, 1, pos-1) : A_LoopField ; varName contains string like "A_BatchLines"
			this.m_storage[varName] := %varName% ; Remember current value; statement '%varName%' retrieves actual value from f.e. A_BatchLines builitin variable

			if (hasNewValueToSet) {
				newValue := SubStr(A_LoopField, pos+1) ; Assume that all after '=' is a new value for variable
				this[SubStr(varName, 3)](newValue) ; Set new value for builtin variable by dynamically calling one of our wrapper methods below (more about dynamic method calling: https://www.autohotkey.com/docs/Objects.htm#Usage_Objects)
			}
		}
	}

	__Delete() {
		; MsgBox % "Start restoring A_-variables:`n`n" CommonUtils.ObjToString(this.m_storage)
		for varName, varVal in this.m_storage {
			this[SubStr(varName, 3)](varVal)
		}
	}

	__Call(methodName, args*) {
		if (!IsFunc(this[methodName])) {
			Throw "You're trying to remember value of 'A_" methodName "' variable, but method '" methodName "(val)' doesn't exist in class '" this.__Class "'. Please, add the missing method and try again."
		}
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

	TitleMatchMode(val) {
		SetTitleMatchMode % val
	}

	WinDelay(val) {
		SetWinDelay % val
	}

	DetectHiddenWindows(val) {
		DetectHiddenWindows % val
	}

	m_storage := {}
}
