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
 * The line:
 * @code{.ahk}
   raii := new AVarValuesRollback("A_TitleMatchMode=RegEx|A_BatchLines=44|A_WinDelay=96")
   ;...
 * @endcode
 *
 * Is equivalent to:
 * @code{.ahk}
   prevTitleMatchMode := A_TitileMatchMode
   prevBatchLines := A_BatchLines
   prevWinDelay := A_WinDelay
   ;...
   SetTitleMatchMode %prevTitleMatchMode%
   SetBatchLines %prevBatchLines%
   SetWinDelay %prevWinDelay%
 * @endcode
 *
 * @warning Avoid using multiple AVarValuesRollback objects **for same A_-varibale** inside the same
 *          function scope. Seems like objects' destruction order in AutoHotkey is not determined so
 *          pay attention if you use multiple RAII objects at the same time this way. In this case
 *          you need manually destroy additional AVarValuesRollback objects by assigning empty
 *          string "" to them in right time because otherwise they may leave your A_-variables at
 *          inconsistent state
 *
 * Usage:
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
		; MsgBox % "Start restoring A_-variables:`n`n" ObjToString(this.m_storage)
		for varName, varVal in this.m_storage {
			this[SubStr(varName, 3)](varVal)
		}
	}

	__Call(methodName, args*) {
		if (!IsFunc(this[methodName])) {
			Throw "You're trying to remember value of 'A_" methodName "' variable, but method '" methodName
			    . "(val)' doesn't exist in class '" this.__Class
			    . "'. Please, add the missing method and try again."
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