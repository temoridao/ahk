/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\ImmutableClass.ahk
#include %A_LineFile%\..\JoyButtons.ahk
#include %A_LineFile%\..\Funcs.ahk

/**
 * Contains utility functions for joysticks (Dinput/Xinput independent)
 */
class JoyUtil extends ImmutableClass
{
;public:

	/**
	 * Check whether the specified gamepad is physically connected and/or can be accessed by
	 * AutoHotkey
	 *
	 * @param   joyIndex  Gamepad's index
	 *
	 * @return  @c true if the specified gamepad is connected, @c fsalse otherwise
	 */
	isConnected(joyIndex := "1") {
		return GetKeyState(joyIndex "JoyInfo")
	}

	/**
	 * Detect valid joystick available on the system
	 *
	 * @return  Index (1-based) of the first valid joystick found on the system, 0 if none
	 */
	validJoyIndex() {
		Loop 16 {
			if (name := GetKeyState(A_Index "JoyName")) {
				return A_Index
			}
		}

		return 0
	}

	povDirection(joyIndex := "") {
		POV := GetKeyState(joyIndex "JoyPOV")  ; Get position of the POV control.
		; Some joysticks might have a smooth/continuous POV rather than one in fixed increments.
		; To support them all, use a range:
		result := ""
		if (POV < 0)                        ; No angle to report
			result := ""
		else if (POV > 31500)               ; 315 to 360 degrees: Forward
			result := "Up"
		else if POV between 0 and 4500      ; 0 to 45 degrees: Forward
			result := "Up"
		else if POV between 4501 and 13500  ; 45 to 135 degrees: Right
			result := "Right"
		else if POV between 13501 and 22500 ; 135 to 225 degrees: Down
			result := "Down"
		else                                ; 225 to 315 degrees: Left
			result := "Left"
		return result
	}

	ltPressed(joyIndex := "", mode:="") {
		if (!mode)
			mode := JoyButtons.JoyMode
		return (mode = "xinput") ? Round(GetKeyState(joyIndex "Joy" JoyLT(mode))) > 50 ;If left analog trigger is pressed (50 in non-pressed state)
		                         : GetKeyState(joyIndex "Joy" JoyLT(mode), "P")
	}
	rtPressed(joyIndex := "", mode:="") {
		if (!mode)
			mode := JoyButtons.JoyMode
		return (mode = "xinput") ? Round(GetKeyState(joyIndex "Joy" JoyRT(mode))) < 50 ;If right analog trigger is pressed (50 in non-pressed state)
		                         : GetKeyState(joyIndex "Joy" JoyRT(mode), "P")
	}
}

/**
 * Helper class to calculate gamepad analog sticks values
 *
 * @code{.ahk}
    #include <JoyUtil>

    ;axis id for XInput compatible gamepad here
    jvl := new JoyStickValues("X", "Y")
    jvr := new JoyStickValues("U", "R")

    ;or using convenience functions from JoyButtons.ahk:
    ; jvl := new JoyStickValues(JoyLSxAxis(), JoyLSyAxis())
    ; jvr := new JoyStickValues(JoyRSxAxis(), JoyRSyAxis())

    Loop {
    	ToolTip % jvl.JoyIndex " joy left stick: " jvl.Direction " [" jvl.DeltaX "; " jvl.DeltaY "]`n"
    	        . jvr.JoyIndex " joy right stick: " jvr.Direction "[ " jvr.DeltaX "; " jvr.DeltaY "]"
    	Sleep 100
    }
 * @endcode
 */
class JoyStickValues {
	/**
	 * Constructor
	 *
	 * @param   xAxis     The stick's X analog axis id as described for builtin GetKeyState() function
	 * @param   yAxis     The stick's Y analog axis id as described for builtin GetKeyState() function
	 * @param   joyIndex  The joy index to query values from as described in builtin GetKeyState()
	 *                    function documentation
	 */
	__New(xAxis, yAxis, joyIndex := 1) {
		this.m_xAxis := xAxis
		this.m_yAxis := yAxis
		this.JoyIndex := joyIndex
	}

	DeltaX[] {
		get {
			JoyX := Round(GetKeyState(this.m_joyHotkeyPrefix . this.m_xAxis))
			dx := JoyX - this.m_stickAxisCenteredValue
			; OutputDebug % "dx: " dx " JoyX: " JoyX
			return dx
		}

		set {
		}
	}

	DeltaY[] {
		get {
			JoyY := Round(GetKeyState(this.m_joyHotkeyPrefix . this.m_yAxis))
			dy := JoyY - this.m_stickAxisCenteredValue
			; OutputDebug % "dy: " dy " JoyY: " JoyY
			return dy
		}

		set {
		}
	}

	XSensitivity[] {
		get {
			return this.m_xSensitivity
		}
		set {
			;Set correctly bounded value, but return original value to allow chaining of assignments
			this.m_xSensitivity := Clamp(value, 1, 50)
			return value
		}
	}

	YSensitivity[] {
		get {
			return this.m_ySensitivity
		}
		set {
			this.m_ySensitivity := Clamp(value, 1, 50)
			return value
		}
	}

	/**
	 * General direction of analog stick with respect to @property XSensitivity
	 * and @property YSensitivity
	 */
	Direction[] {
		get {
			dx := this.DeltaX
			dy := this.DeltaY

			if (horizontalSensitivityPassed := Abs(dx) >= this.XSensitivity) {
				return dx > 0 ? "Right"
				     : dx < 0 ? "Left" : ""
			}

			if (verticalSensitivityPassed := Abs(dy) >= this.YSensitivity) {
				return dy > 0 ? "Down"
				     : dy < 0 ? "Up" : ""
			}

			return "xyCentered"
		}

		set {
		}
	}

	/**
	 * 1-based gamepad index to query values from
	 */
	JoyIndex[] {
		get {
			return this.m_joyIndex
		}
		set {
			this.m_joyIndex := value
			this.m_joyHotkeyPrefix := this.m_joyIndex . "Joy"
		}
	}

;private:
	m_stickAxisCenteredValue := 50 ;This value reported by LS/RS in default centered position
	m_joyIndex := 1
	m_joyHotkeyPrefix := ""
	m_xAxis := ""
	m_yAxis := ""
	m_xSensitivity := 1
	m_ySensitivity := 1
}

/**
 * Helper function to define gamepad hotkeys
 *
 * NOTE: requires 'global g_joystickPrefix' variable in the calling script
 * Parameters have the same meaning as in builtin Hotkey command
 *
 * @code{.ahk}
   #include <JoyUtil>

   global g_joystickNumber := 1 ;Will bind hotkeys to first joystick

   jh(JoyA(), "MsgBox")

   HotkeyIf(Func("WinActive").Bind("ahk_exe notepad.exe", "", "", ""))
   	jh(JoyA(), Func("MsgBox").Bind("notepad window active"))
   HotkeyIf() ;Disable context sensitivity
 * @endcode
 */
jh(KeyName, Label := "", Options := "") {
	Hotkey % g_joystickNumber . "Joy" . KeyName, %Label%, %Options%
}