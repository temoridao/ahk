/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

/**
 * Helper function to define gamepad hotkeys
 *
 * NOTE: requires 'global g_joystickNumber' variable to be defined in the calling script with index
 * of controlled joystick.
 * Parameters have the same meaning as in builtin @c Hotkey command
 *
 * @code{.ahk}
   #include <jh>

   global g_joystickNumber := 1 ;Will bind hotkeys to first joystick

   jh(JoyA(), Func("MsgBox").Bind("JoyA pressed"))

   HotkeyIf(Func("WinActive").Bind("ahk_exe notepad.exe", "", "", ""))
   	jh(JoyA(), Func("MsgBox").Bind("JoyA pressed and notepad window is active"))
   HotkeyIf() ;Disable context sensitivity
 * @endcode
 */
jh(KeyName, Label := "", Options := "") {
	Hotkey(g_joystickNumber . "Joy" . KeyName, Label, Options)
}