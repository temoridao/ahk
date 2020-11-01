/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\ImmutableClass.ahk
#include %A_LineFile%\..\..\3rdparty\Lib\XInput.ahk

/**
 * Helper utility functions for XInput.ahk library
 *
 * Note that all functions in this class assume that XInput library is already initialized
 * with call to @c XInput_Init()
 */
class XinputUtil extends ImmutableClass
{
;public:
	/**
	 * Determines whether the specified gamepad is functional XInput device
	 *
	 * @param   gamepadIndex  The gamepad index (start from 0)
	 *
	 * @return  @c true if the specified gamepad is functional XInput gamepad and @c false otherwise
	 */
	isConnected(gamepadIndex) {
		static XINPUT_FLAG_GAMEPAD := 0x00000001
		return XInput_GetCapabilities(gamepadIndex, XINPUT_FLAG_GAMEPAD)
	}

;private:
}