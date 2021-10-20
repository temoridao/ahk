/**
 * @file
 * Contains named functoinal wrappers around joystick button indices
 *
 * Each function is able to return joy number depending on the gamepad mode (XInput or Dinput)
 * passed as parameter @c mode. To determine current gamepad mode see @ref XinputUtil.isConnected().
 * To determine if gamepad is functional (in either mode) and can be accessed by AutoHotkey see
 * @ref JoyUtil.isConnected()
 *
 * Using these wrappers make code more clear and self-documented, f.e.:
 *
 * @code{.ahk}
   #incldue <JoyButtons>

   global g_JoyNumber := 1
        , g_JoystickPrefix :=  g_JoyNumber "Joy"

   jh(JoyLS(), "onLeftStickPress")
   jh(JoyBack(), Func("showMessage").Bind("You pressed <Back> button!"))


   jh(KeyName, Label := "", Options := "") { ;jh -> JoyHotkey
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

/**
 * Contains global joy mode for gamepads' hotkeys. If no explicit @c mode parameter passed
 * to functions below, the value from this global static variable is taken.
 * This avoids passing @c mode parameter on each function call.
 * Example:
 * @code{.ahk}
   #include <JoyButtons>
   #include <XinputUtil>

   XInput_Init() ;Initialize XInput.ahk library
   JoyButtons.JoyMode := XinputUtil.isConnected(0) ? "xinput" : "dinput" ;Initialize global mode

   Hotkey % "Joy" JoyA(), % "hello" ;Press <A> on joystick to open message box
   ;altenatively: Hotkey % "Joy" JoyA(XinputUtil.isConnected(0) ? "xinput" : "dinput"), % "hello"

   hello() {
   	MsgBox % "Hello! Current mode is '" JoyButtons.JoyMode "'"
   }
 * @endcode
 */
class JoyButtons {
	static JoyMode := "xinput"
}

JoyA(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 1 : 3
}
Joy1() {
	return JoyA()
}

JoyB(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return 2
}
Joy2() {
	return JoyB()
}

JoyX(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 3 : 4
}
Joy3() {
	return JoyX()
}

JoyY(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 4 : 1
}
Joy4() {
	return JoyY()
}

JoyLB(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return 5
}
Joy5() {
	return JoyLB()
}

JoyRB(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return 6
}
Joy6() {
	return JoyRB()
}

JoyBack(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 7 : 9
}
Joy7() {
	return JoyBack()
}

JoyStart(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 8 : 10
}
Joy8() {
	return JoyStart()
}

JoyLS(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 9 : 11
}
Joy9() {
	return JoyLS()
}
JoyLSxAxis(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return "X"
}
JoyLSyAxis(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return "Y"
}

JoyRS(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? 10 : 12
}
Joy10() {
	return JoyRS()
}
JoyRSxAxis(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? "U" : "Z"
}
JoyRSyAxis(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return "R"
}

JoyLT(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? "Z" : 7
}
JoyRT(mode:="") {
	if (!mode)
		mode := JoyButtons.JoyMode

	return (mode = "xinput") ? "Z" : 8
}