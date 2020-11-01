/**
 * @file
 * Contains named functoinal wrappers around joystick button indices
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

JoyA() {
	return 1
}
Joy1() {
	return JoyA()
}

JoyB() {
	return 2
}
Joy2() {
	return JoyB()
}

JoyX() {
	return 3
}
Joy3() {
	return JoyX()
}

JoyY() {
	return 4
}
Joy4() {
	return JoyY()
}

JoyLB() {
	return 5
}
Joy5() {
	return JoyLB()
}

JoyRB() {
	return 6
}
Joy6() {
	return JoyRB()
}

JoyBack() {
	return 7
}
Joy7() {
	return JoyBack()
}

JoyStart() {
	return 8
}
Joy8() {
	return JoyStart()
}

JoyLS() {
	return 9
}
Joy9() {
	return JoyLS()
}

JoyRS() {
	return 10
}
Joy10() {
	return JoyRS()
}
