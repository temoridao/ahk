/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\ImmutableClass.ahk

/**
 * Contains utility functions for joysticks
 */
class JoyUtil extends ImmutableClass
{
;public:
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

	ltPressed(joyIndex := "") {
		return Round(GetKeyState(joyIndex "JoyZ")) > 50 ;If left analog trigger is pressed (50 in non-pressed state)
	}
	rtPressed(joyIndex := "") {
		return Round(GetKeyState(joyIndex "JoyZ")) < 50 ;If right analog trigger is pressed (50 in non-pressed state)
	}
}