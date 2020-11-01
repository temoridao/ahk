/**
 * @file
 * Contains named functoinal wrappers around joystick button indices
 *
 * Each function is able to return joy number depending on the gamepad mode (XInput or Dinput)
 * passed as parameter @c mode. To determine current gamepad mode see @ref XinputUtil.isConnected().
 * To determine if gamepad is functional (in either mode) and can be accessed by AutoHotkey see
 * @ref JoyUtil.isFunctional()
 *
 * Using these wrappers make code more clear and self-documented, f.e.:
 *
 * @code{.ahk}
   #incldue <JoyButtons>

   global g_JoyNumber := 1
        , g_JoystickPrefix := "Joy" g_JoyNumber

   jh(JoyLS(), "onLeftStickPress")
   jh(JoyBack(), Func("showMessage").Bind("You pressed <Back> button!"))

   ;jh -> JoyHotkey
   jh(KeyName, Label := "", Options := "") {
   	Hotkey % g_JoystickPrefix . KeyName, %Label%, %Options%
   }
   onLeftStickPress() {
   	MsgBox You pressed Left Stick!
   }
   showMessage(message) {
   	MsgBox % message
   }
 * @endcode
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

JoyA(mode:="xinput") {
	return (mode = "xinput") ? 1 : 3
}
Joy1() {
	return JoyA()
}

JoyB(mode:="xinput") {
	return 2
}
Joy2() {
	return JoyB()
}

JoyX(mode:="xinput") {
	return (mode = "xinput") ? 3 : 4
}
Joy3() {
	return JoyX()
}

JoyY(mode:="xinput") {
	return (mode = "xinput") ? 4 : 1
}
Joy4() {
	return JoyY()
}

JoyLB(mode:="xinput") {
	return 5
}
Joy5() {
	return JoyLB()
}

JoyRB(mode:="xinput") {
	return 6
}
Joy6() {
	return JoyRB()
}

JoyBack(mode:="xinput") {
	return (mode = "xinput") ? 7 : 9
}
Joy7() {
	return JoyBack()
}

JoyStart(mode:="xinput") {
	return (mode = "xinput") ? 8 : 10
}
Joy8() {
	return JoyStart()
}

JoyLS(mode:="xinput") {
	return (mode = "xinput") ? 9 : 11
}
Joy9() {
	return JoyLS()
}
JoyLSxAxis(mode:="xinput") {
	return "X"
}
JoyLSyAxis(mode:="xinput") {
	return "Y"
}

JoyRS(mode:="xinput") {
	return (mode = "xinput") ? 9 : 12
}
Joy10() {
	return JoyRS()
}
JoyRSxAxis(mode:="xinput") {
	return (mode = "xinput") ? "U" : "Z"
}
JoyRSyAxis(mode:="xinput") {
	return "R"
}

JoyLt(mode:="xinput") {
	return (mode = "xinput") ? "Z" : 7
}
JoyRt(mode:="xinput") {
	return (mode = "xinput") ? "Z" : 8
}