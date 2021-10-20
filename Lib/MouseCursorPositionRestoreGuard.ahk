/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\AVarValuesRollback.ahk

/**
 * Remember mouse cursor position on object creation and restore postion upon destruction
 *
 * @code{.ahk}
 	CoordMode Mouse, Screen
 	MouseMove A_ScreenWidth / 2, A_ScreenHeight / 2
 	mcr := new MouseCursorPositionRestoreGuard
 	ToolTip You can move mouse cursor outside of screen center. It will be moved back to the center of screen when script exits (i.e. mcr object above is destroyed)
 	Sleep 5000
 	ExitApp
 * @endcode
 *
 */
class MouseCursorPositionRestoreGuard {
	__New(blockInput := true) {
		this.m_blockInput := blockInput
		this.rememberPosition()
	}

	__Delete() {
		this.restorePosition()
	}

	rememberPosition() {
		if (this.m_blockInput) {
			BlockInput ON
		}

		raii := avarguard("A_CoordModeMouse=Screen")
		MouseGetPos startMouseX, startMouseY

		this.startMouseX := startMouseX
		this.startMouseY := startMouseY
	}
	restorePosition() {
		MouseMove this.startMouseX, this.startMouseY
		if (this.m_blockInput) {
			BlockInput OFF
		}
	}
}