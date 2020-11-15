#include %A_LineFile%\..\..\Lib\Funcs.ahk

;jh - JoyHotkey
;Required 'global g_joystickPrefix' variable in the calling script
jh(KeyName, Label := "", Options := "") {
	Hotkey % g_joystickPrefix . KeyName, %Label%, %Options%
}
