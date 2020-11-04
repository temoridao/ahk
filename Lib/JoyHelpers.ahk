#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

;jh - JoyHotkey
;Required 'global g_joystickPrefix' variable in the calling script
jh(KeyName, Label := "", Options := "") {
	Hotkey % g_joystickPrefix . KeyName, %Label%, %Options%
}
FSend(keys) {
	return Func("Send").Bind(keys)
}
_F(funcName, params*) {
	return Func(funcName).Bind(params*)
}