/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\..\3rdparty\Lib\XInput.ahk
#include %A_LineFile%\..\JoyUtil.ahk
/**
 * Helper utility functions for XInput.ahk library
 *
 * Note that all functions in this class (as well as XInput library) expect joystick index
 * starting from 0 in contrast to AutoHotkey joysticks numbering which is started from 1
 */
class XinputUtil extends StaticClassBase
{
;public:
	/**
	 * Determines whether the specified gamepad is functional XInput device
	 *
	 * NOTE: this function assumes that XInput library is already initialized with a
	 * call to @ref XInput_Init()
	 *
	 * @param   gamepadIndex  The gamepad index (start from 0)
	 *
	 * @return  @c true if the specified @p gamepadIndex is connected and functional XInput gamepad
	 *          and @c false otherwise
	 */
	isConnected(gamepadIndex) {
		return XInput_GetState(gamepadIndex) ? true : false
	}

	/**
	 * Initializes JoyButtons.JoyMode global config variable with actual API mode for joystick @p
	 * gamepadIndex. Possible resulting values of @c JoyButtons.JoyMode are "XInput" or "DInput". This
	 * function is useful for joysticks which have physical switch to change input mode.
	 *
	 * @param   gamepadIndex  The gamepad index (start from 1)
	 */
	initJoyMode(gamepadIndex) {
		if (!_XInput_hm) {
			Throw "XInput library not initialized. Call XInput_Init() first"
		}
		if (gamepadIndex < 1) {
			Throw "Invalid parameters"
		}

		xIndex := JoyUtil.toXinputJoyIndex(gamepadIndex)
		if (xIndex = -1) {
			return "dinput"
		}

		if (XinputUtil.isConnected(xIndex)) {
			JoyButtons.JoyMode := "xinput"
		} else {
			Throw "Detected XInput gamepad index " xIndex " which is not recognized by xinput.dll"
		}
	}
}