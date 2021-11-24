/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

/**
 * Register tray icon mouse click handlers
 *
 * @code{.ahk}
   trayHandler := new TrayIconClickHandler({"R2" : "RbuttonDoubleClick"
                                          , "M2" : "MbuttonDoubleClick"
                                          , "L1" : "LbuttonSingleClick" })
   RbuttonDoubleClick() {
   	MsgBox % A_ThisFunc
   }
   MbuttonDoubleClick() {
   	MsgBox % A_ThisFunc
   }
   LbuttonSingleClick() {
   	MsgBox % A_ThisFunc
   }
 * @endcode
 */
class TrayIconClickHandler
{
	static cSupportedMouseButtons := ["L", "R", "M"]

;public:
	__New(callbacksMap, maxDelayBetweenClicks := 200) {
		;Check if click count is explicitly specified for each mouse button
		for key, value in callbacksMap
			if (StrLen(key) = 1)
				throw Exception("Number of clicks not found for mouse button """ key """" )

		this.m_callbacksMap := callbacksMap
		this.m_maxDelayBetweenClicks := maxDelayBetweenClicks

		this.m_buttonToClickCount := {}
		for i, button in TrayIconClickHandler.cSupportedMouseButtons {
			this.m_buttonToClickCount[button] := 0
		}
		this.setEnabled(true)
	}

	enabled() {
		return this.m_enabled
	}

	setEnabled(enabled) {
		if (this.m_enabled = enabled) {
			return
		}
		this.m_enabled := enabled
		if (enabled) {
			this.m_functor := ObjBindMethod(this.base, "onTrayIconClick", &this)
			OnMessage(0x404, this.m_functor)
		} else {
			OnMessage(0x404, this.m_functor, 0)
			this.m_functor := ""
		}
	}

;private:
	__Delete() {
		this.setEnabled(false)
	}

	onTrayIconClick(thisPointer, wParam, lParam) {
		this := Object(thisPointer)

		mouseButton := ""
		if (lParam = 0x201) { ; LEFT CLK
			mouseButton := "L"
		} else if (lParam = 0x203) { ; LEFT DBCLK
			mouseButton := "L"
		} else if (lParam = 0x205) { ; RIGHT CLK
			mouseButton := "R"
		} else if (lParam = 0x208) { ; MIDDLE CLK
			mouseButton := "M"
		}
		if (!mouseButton) {
			return
		}

		this.m_buttonToClickCount[mouseButton]++
		if (!this.m_timerInProgress) {
			f := ObjBindMethod(this.base, "processClick", &this, mouseButton)
			SetTimer % f, % -this.m_maxDelayBetweenClicks
			this.m_timerInProgress := true
		}

		return 0
	}

	processClick(thisPointer, mouseButton) {
		this := Object(thisPointer)

		clickCount := this.m_buttonToClickCount[mouseButton]
		; logDebug("About to process {}{} click", mouseButton, clickCount)
		f := this.m_callbacksMap[mouseButton . clickCount]
		f := IsObject(f) ? f : Func(f)

		if (!f) {
			if (mouseButton = "R" && clickCount = 1) {
				Menu, Tray, Show ; launch standard menu
			}
		} else {
			f.Call()
		}

		this.m_buttonToClickCount[mouseButton] := 0
		this.m_timerInProgress := false
	}

	m_enabled := false
}