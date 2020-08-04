/**
 * Description:
 *    %TODO%
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

Clamp(value, min, max) {
	if (min > max) {
		Throw "Invalid parameters: min > max"
	}

	return value < min ? min
	     : value > max ? max
	     : value
}
