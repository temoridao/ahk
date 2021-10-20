/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\JoyButtons.ahk
#include %A_LineFile%\..\Funcs.ahk

/**
 * Contains utility functions for joysticks (DInput/XInput independent)
 */
class JoyUtil extends StaticClassBase
{
;public:

	;The stick axis centered position value reported by gamepad in its default state
	static DefaultCenteredValueForAxis := 50

	;This is a name of generic XInput gamepad according to registry
	static xInputDeviceName := "Controller (USB Gamepad Controller)"

	/**
	 * Check whether the specified gamepad is physically connected and/or can be accessed by
	 * AutoHotkey
	 *
	 * @param   joyIndex  Gamepad's index
	 *
	 * @return  @c true if the specified gamepad is connected, @c false otherwise
	 */
	isConnected(joyIndex := "1") {
		return GetKeyState(joyIndex "JoyName")
	}

	/**
	 * Detect valid joystick available on the system
	 *
	 * @param   xinputOnly  Search for XInput-compatible gamepads only
	 *
	 * @return  Index (1-based consumable by AHK functions) of the first valid joystick found on the
	 *          system, 0 if none. Note that if @p xinputOnly is @c true (default) the return value
	 *          -1 indicates the absence of connected gamepads.
	 */
	validJoyIndex(xinputOnly := true) {
		if (xinputOnly) {
			return JoyUtil.getValidXInputGamepadAhkIndex()
		}

		Loop 16 {
			if (name := GetKeyState(A_Index "JoyName")) {
				return A_Index
			}
		}

		return 0
	}

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

	ltPressed(joyIndex := "", mode:="") {
		if (!mode)
			mode := JoyButtons.JoyMode
		return (mode = "xinput") ? Round(GetKeyState(joyIndex "Joy" JoyLT(mode))) > JoyUtil.DefaultCenteredValueForAxis
		                         : GetKeyState(joyIndex "Joy" JoyLT(mode), "P")
	}
	rtPressed(joyIndex := "", mode:="") {
		if (!mode)
			mode := JoyButtons.JoyMode
		return (mode = "xinput") ? Round(GetKeyState(joyIndex "Joy" JoyRT(mode))) < JoyUtil.DefaultCenteredValueForAxis
		                         : GetKeyState(joyIndex "Joy" JoyRT(mode), "P")
	}

	/**
	 * Ask user to press a button on gamepad and returns that gamepad's index suitable for use in AHK
	 * code
	 *
	 * Also this function set the @c JoyButtons.JoyMode global state depending on detected gamepad
	 *
	 * @param   timeoutSec  The overall timeout in seconds for this function to wait for @p button
	 *                      press.
	 * @param   button      The button on gamepad to ask. "A" by default, but may be X, Y, B, Start,
	 *                      etc. See functions started with "Joy" in JoyButtons.ahk for all possible
	 *                      variants.
	 * @param   cancelKey   This keyboard key when pressed cancels the polling loop and forces
	 *                      function to return immediately
	 *
	 * @return  Gamepad index suitable for use in to use in @c Hotkey command for example
	 */
	selectGamepadByButtonPress(timeoutSec := 60, button := "A", cancelKey := "Esc") {
		funcStartTime := A_Now
		while (true) {
			Loop 16 {
				if (GetKeyState(cancelKey, "P")) {
					return 0
				}

				if (xinputPressed := GetKeyState(A_Index "Joy" Joy%button%("xinput"), "P")) {
					JoyButtons.JoyMode := "xinput"
					return A_Index
				}

				if (dinputPressed := GetKeyState(A_Index "Joy" Joy%button%("dinput"), "P")) {
					JoyButtons.JoyMode := "dinput"
					return A_Index
				}
			}

			now := A_Now
			now -= funcStartTime, Seconds
			if (now >= timeoutSec) {
				return 0
			}

			Sleep 100
		}
	}

	/**
	 * Convert  1-based AutoHotkey's joy index to 0-based XInput gamepad index suitable for use with
	 * system functions from xinput.dll
	 *
	 * @param   ahkJoyIndex  The ahk joy index (1-based)
	 *
	 * @return  XInput joy index (0-based) or -1 if the conversion not possible
	 */
	toXinputJoyIndex(ahkJoyIndex) {
		xInputIndex := -1
		for i, caps in JoyEnumerator.enumerateJoys() {
			if (caps.oemNameFromRegistry = JoyUtil.xInputDeviceName) {
				++xInputIndex
				if (i = ahkJoyIndex) {
					break
				}
			}
		}
		return xInputIndex
	}

	/**
	 * Get AHK 1-based index of the first available XInput gamepad
	 *
	 * @param   excludeAhkIndex  If specified the function returns the first available gamepad index
	 *                           not equal to this parameter's value
	 *
	 * @return  1-based AHK index or 0 in case of failure (no gamepads connected or there is no
	 *          connected gamepads other than @p excludeAhkIndex if that parameter is specified)
	 */
	getValidXInputGamepadAhkIndex(excludeAhkIndex := 0) {
		indices := []
		for ahkJoyIndex, caps in JoyEnumerator.enumerateJoys() {
			if ((caps.oemNameFromRegistry = JoyUtil.xInputDeviceName)) {
				indices.Push(ahkJoyIndex)
			}
		}

		if (!indices.Length()) {
			return 0
		}

		if (excludeAhkIndex = 0) {
			return indices[1]
		}

		;Try to find next index greater than excludeAhkIndex
		resultIndex := 0
		for each, index in indices {
			if (index > excludeAhkIndex) {
				resultIndex := index
				break
			}
		}
		if (resultIndex) {
			return resultIndex
		}

		;Try to find next index which is less than excludeAhkIndex (wrap around behaviour)
		for each, index in indices {
			if (index < excludeAhkIndex) {
				resultIndex := index
				break
			}
		}

		return resultIndex ? resultIndex : 0
	}
}

/**
 * Helper class to calculate gamepad analog sticks values
 *
 * @code{.ahk}
    #include <JoyUtil>

    ;axis id for XInput compatible gamepad here
    jvl := new JoyStickValues("X", "Y")
    jvr := new JoyStickValues("U", "R")

    ;or using convenience functions from JoyButtons.ahk:
    ; jvl := new JoyStickValues(JoyLSxAxis(), JoyLSyAxis())
    ; jvr := new JoyStickValues(JoyRSxAxis(), JoyRSyAxis())

    Loop {
    	ToolTip % jvl.JoyIndex " joy left stick: " jvl.Direction " [" jvl.DeltaX "; " jvl.DeltaY "]`n"
    	        . jvr.JoyIndex " joy right stick: " jvr.Direction " [ " jvr.DeltaX "; " jvr.DeltaY "]"
    	Sleep 100
    }
 * @endcode
 */
class JoyStickValues {
;public:

	/**
	 * @param   xAxisId                 The stick's X analog axis id as described for builtin
	 *                                  GetKeyState() function
	 * @param   yAxisId                 The stick's Y analog axis id as described for builtin
	 *                                  GetKeyState() function
	 * @param   joyIndex                The joy index to query values from as described in builtin
	 *                                  GetKeyState() function documentation
	 * @param   stickAxisCenteredValue  The stick axis centered position value reported by gamepad
	 *                                  in its default state. This will be an initial value of
	 *                                  @property StickAxisCenteredValue. Use JoyTest.ahk script
	 *                                  to determine this value if default value of
	 *                                  @c JoyUtil.DefaultCenteredValueForAxis is not
	 *                                  suitable for your gamepad
	 */
	__New(xAxisId, yAxisId, joyIndex := 1, stickAxisCenteredValue := "default") {
		this.m_xAxisId := xAxisId
		this.m_yAxisId := yAxisId
		if (stickAxisCenteredValue = "default") {
			stickAxisCenteredValue := JoyUtil.DefaultCenteredValueForAxis
		}
		this.StickAxisCenteredValue := stickAxisCenteredValue
		this.JoyIndex := joyIndex
	}

	/**
	 * X axis current value in [-1.0, 1.0] range
	 */
	DeltaX[] {
		get {
			JoyX := GetKeyState(this.m_joyHotkeyPrefix . this.m_xAxisId)
			dx := (JoyX - this.m_stickAxisCenteredValue) / this.m_axisValueDivisor
			; OutputDebug % "dx: " dx " JoyX: " JoyX
			return dx
		}

		set {
		}
	}

	/**
	 * Y axis current value in [-1.0, 1.0] range
	 */
	DeltaY[] {
		get {
			JoyY := GetKeyState(this.m_joyHotkeyPrefix . this.m_yAxisId)
			dy := (JoyY - this.m_stickAxisCenteredValue) / this.m_axisValueDivisor
			; OutputDebug % "dy: " dy " JoyY: " JoyY
			return dy
		}

		set {
		}
	}

	/**
	 * X axis minimal value which must be exceeded by the axis to be considered as "pushed".
	 * For example, the value of this property is used by @property Direction to calculate a
	 * dominant direction of analog stick.
	 * Valid range: [0.0; 1.0]
	 */
	DeadZoneX[] {
		get {
			return this.m_DeadZoneX
		}
		set {
			;Set correctly bounded value, but return original value to allow chaining of assignments
			this.m_DeadZoneX := Clamp(value, 0.0, 1.0)
			return value
		}
	}

	/**
	 * Y axis minimal value which must be exceeded by the axis to be considered as "pushed".
	 * For example, the value of this property is used by @property Direction to calculate a
	 * dominant direction of analog stick.
	 * Valid range: [0.0; 1.0]
	 */
	DeadZoneY[] {
		get {
			return this.m_DeadZoneY
		}
		set {
			this.m_DeadZoneY := Clamp(value, 0.0, 1.0)
			return value
		}
	}

	/**
	 * This value reported by L/R analog sticks in default centered position (probably non-zero) and
	 * will be used for normalization of the value reported by @property DeltaX and @property DeltaY
	 */
	StickAxisCenteredValue[] {
		get {
			return this.m_stickAxisCenteredValue
		}
		set {
			this.m_axisValueDivisor := Clamp(1.0 * (this.MaxAxisRangeValue - value), 1, 100)
			return this.m_stickAxisCenteredValue := value
		}
	}

	/**
	 * General direction of analog stick
	 *
	 * Possible values: "xyCentered", "Left", "Right", "Up", "Down"
	 * Axis @c value below is a value of @property DeltaX or @property DeltaY.
	 * Rules of @property Direction calculation:
	 * - Horizontal axis takes precedence in case of both axes are equal and non-zero
	 * - If both axes values not exceed their corresponding dead zones, this is "xyCentered", i.e. resting state
	 * - Only one axis with largest absolute value will be considered as candidate
	 *   - If candidate's axis value > 0, this is "Right" for horizontal axis and "Down" for vertical
	 *   - If candidate's axis value < 0, this is "Left" for horizontal axis and "Up" for vertical
	 */
	Direction[] {
		get {
			dx := this.DeltaX
			dy := this.DeltaY
			absDx := Abs(dx)
			absDy := Abs(dy)

			if (absDx < this.DeadZoneX && absDy < this.DeadZoneY) {
				return "xyCentered"
			}

			if (absDx >= this.DeadZoneX && (absDx > absDy || absDx = absDy)) {
				return dx > 0 ? "Right" : "Left"
			}
			if (absDy >= this.DeadZoneY ) {
				return dy > 0 ? "Down" : "Up"
			}
		}

		set {
		}
	}

	/**
	 * 1-based gamepad index to query values from
	 */
	JoyIndex[] {
		get {
			return this.m_joyIndex
		}
		set {
			this.m_joyIndex := value
			this.m_joyHotkeyPrefix := this.m_joyIndex . "Joy"
			return value
		}
	}

;private:
	static DefaultDeadZone := 0.1
	static MaxAxisRangeValue := 100

	m_stickAxisCenteredValue := 0
	m_axisValueDivisor := 1
	m_joyIndex := 1
	m_joyHotkeyPrefix := ""
	m_xAxisId := ""
	m_yAxisId := ""
	m_DeadZoneX := this.DefaultDeadZone
	m_DeadZoneY := this.DefaultDeadZone
}

/**
 * Helper class which allows to remap gamepad's analog sticks to mouse cursor movement
 *
 * Here is an example how to remap right analog stick of the first gamepad in the system
 * to mouse movement:
 * @code{.ahk}
   #Persistent
   global g_joystickNumber := 1
        , g_jvr := new JoyStickValues(JoyRSxAxis(), JoyRSyAxis(), g_joystickNumber)
        , g_rightStickToMouseRemapper := new JoyStickToMouseRemapper(g_jvr)

   SetTimer("WatchRightStick", 30, 1) ;Mouse emulation

   WatchRightStick() {
   	;g_jvr.DeltaX, g_jvr.DeltaY, g_jvr.Direction provide actual gamepad right stick state
   	g_rightStickToMouseRemapper.update()
   }
 * @code
 */
class JoyStickToMouseRemapper {
;public:

	/**
	 * @param   joyStickValues  An instance of @ref JoyStickValues class. It will read and provide
	 *                          actual values from analog sticks
	 * @param   invertY         Set to @c true if need to invert cursor's vertical axis movement
	 * @param   invertX         Set to @c true if need to invert cursor's horizontal axis movement
	 */
	__New(joyStickValues, invertY := false, invertX := false) {
		this.InvertY := invertY
		this.InvertX := invertX
		this.m_joyStickValues := joyStickValues
	}

	/**
	 * Updates the remapper's state
	 *
	 * Moves mouse cursor depending on current value of the analog sticks provided by the @ref
	 * JoyStickValues object passed to constructor of this @ref JoyStickToMouseRemapper instance. This
	 * function typically should be called as @c SetTimer routine. See code example in the
	 * documentation of this class.
	 *
	 * @param   speed  The multiplier of cursor movement distance. The greater this value — the faster
	 *                 mouse cursor is moving in the current direction of the joystick analog stick
	 *
	 * @return  @c true if any of the axes exceed their sensitivity (defined by @property DeadZoneX
	 *          and @property DeadZoneY) i.e. if some potentially assigned action was executed
	 */
	update(speed := 50) {
		dx := this.m_joyStickValues.DeltaX
		dy := this.m_joyStickValues.DeltaY
		xPassed := Abs(dx) >= this.m_joyStickValues.DeadZoneX
		yPassed := Abs(dy) >= this.m_joyStickValues.DeadZoneY
		if (xPassed || yPassed) {
			mouseDeltaX := xPassed ? (dx * speed * this.m_xAxisMutliplier) : 0
			mouseDeltaY := yPassed ? (dy * speed * this.m_yAxisMutliplier) : 0
			CoordMode Mouse, Screen
			MouseGetPos mx, my
			DllCall("SetCursorPos"
				, "int", mx + mouseDeltaX
				, "int", my + mouseDeltaY)
			return true
		}
	}

	/**
	 * Invert cursor's horizontal axis movement
	 */
	InvertX[] {
		get {
			return this.m_invertX
		}
		set {
			this.m_xAxisMutliplier := value ? -1 : 1
			return this.m_invertX := value
		}
	}

	/**
	 * Invert cursor's vertical axis movement
	 */
	InvertY[] {
		get {
			return this.m_invertY
		}
		set {
			this.m_yAxisMutliplier := value ? -1 : 1
			return this.m_invertY := value
		}
	}

;private:
	m_invertX := false
	m_invertY := false
	m_joyStickValues := ""

	m_yAxisMutliplier := 1
	m_xAxisMutliplier := 1
}

/**
 * Helper class which allows to remap gamepad analog sticks to keyboard and/or mouse keys
 *
 * Here is an example how to remap left analog stick of the first gamepad in the system
 * to WASD keys:
 *
 * @code{.ahk}
   #Persistent
   SetKeyDelay, 30, 30

   ;{ Config Section
   	global g_joystickNumber := 1
   	     , g_LStickDirectionToAutoRepeatKeys :=
   				 (LTrim Join Comments
   				 {
   						"Left" : "a", ;(Tip: can be callable object f.e. Func("Send").Bind("{Volume_Down}") to decrease system volume when pushing analog stick to the left)
   						"Right": "d", ;(Tip: can be callable object f.e. Func("Send").Bind("{Volume_Up}") to increase system volume when pushing analog stick to the right)
   						"Up"   : "w", ;Push stick upward to start holding 'w' key
   						"Down" : "s"  ;Push stick downward to start holding 's' key
   				 }
   				 )
   ;}

   global g_jvl := new JoyStickValues(JoyLSxAxis(), JoyLSyAxis(), g_joystickNumber) ;change g_jvl.DeadZoneX, g_jvl.DeadZoneY if needed
        , g_leftStickKeyRemapper := new JoyStickRemapper(g_jvl, g_LStickDirectionToAutoRepeatKeys)

   SetTimer("WatchLeftStick", A_KeyDelay) ; WASD movement

   WatchLeftStick() {
   	;g_jvl.DeltaX, g_jvl.DeltaY, g_jvl.Direction provide actual gamepad left stick state
   	g_leftStickKeyRemapper.update()
   }
 * @endcode
 *
 */
class JoyStickRemapper {
;public:
	/**
	 * @param   joyStickValues             An instance of @ref JoyStickValues class. It will read and
	 *                                     provide actual values from analog sticks
	 * @param   stickDirectionToActionMap  A map from stick direction to the action to be performed
	 *                                     when stick points to corresponding direction (can be string
	 *                                     for remap behaviour or callable object with Call() method)
	 * @param   useAutorepeat              Set to true (the default) to emulate a keyboard autorepeat
	 *                                     feature i.e. an action from @p stickDirectionToActionMap
	 *                                     will be repeated all time the stick points to that
	 *                                     direction. If this parameter is @c false, an action
	 *                                     (key press or callable's invocation) will be performed only
	 *                                     once until the stick changes its direction
	 */
	__New(joyStickValues, stickDirectionToActionMap, useAutorepeat := true) {
		;initialize array with initial directions
		for dir in this.m_stickDirectionToActionMap {
			this.m_triggeredActions[dir] := {}
		}

		this.m_joyStickValues := joyStickValues
		this.m_stickDirectionToActionMap := stickDirectionToActionMap
		this.m_useAutorepeat := useAutorepeat
	}

	/**
	 * Updates the remapper's state
	 *
	 * Executes assigned remappings and/or callable objects depending on current direction of the
	 * analog sticks provided by the @ref JoyStickValues object passed to constructor of this @ref
	 * JoyStickRemapper instance. This function typically should be called as @c SetTimer routine
	 * with, for example, @c A_KeyDelay interval. See code example in the documentation of this class.
	 *
	 * @return  @c true if any of the axes exceed their sensitivity (defined by @property DeadZoneX
	 *          and @property DeadZoneY) i.e. if some potentially assigned action was executed
	 */
	update() {
		dx := this.m_joyStickValues.DeltaX
		dy := this.m_joyStickValues.DeltaY
		if (xPassed := Abs(dx) >= this.m_joyStickValues.DeadZoneX) {
			dir := dx < 0 ? "Left" : "Right"
			this.applyForDirection(dir)

			otherDir := (dir = "Left") ? "Right" : "Left"
			this.unapplyForDirections([otherDir])
		} else {
			this.unapplyForDirections(["Left", "Right"])
		}

		if (yPassed := Abs(dy) >= this.m_joyStickValues.DeadZoneY) {
			dir := dy < 0 ? "Up" : "Down"
			this.applyForDirection(dir)

			otherDir := (dir = "Up") ? "Down" : "Up"
			this.unapplyForDirections([otherDir])
		} else {
			this.unapplyForDirections(["Up", "Down"])
		}

		return xPassed || yPassed
	}

	/**
	 * Contains @c true if autorepeat feature is active
	 */
	AutoRepeat[] {
		get {
			return this.m_useAutorepeat
		}
		set {
			return this.m_useAutorepeat := value
		}
	}

;private
	applyForDirection(dir) {
		action := this.m_stickDirectionToActionMap[dir]
		if (this.m_useAutorepeat || !this.m_triggeredActions[dir, action]) {
			if (IsObject(action)) {
				action.Call()
			} else {
				Send {%action% down}
			}
			this.m_triggeredActions[dir, action] := true
		}
	}

	unapplyForDirections(dirs) {
		for i, dir in dirs {
			for action in this.m_triggeredActions[dir] {
				if (!IsObject(action)) {
					Send {%action% up}
				}
			}
			this.m_triggeredActions[dir] := {}
		}
	}

	m_useAutorepeat := ""
	m_joyStickValues := ""
	m_triggeredActions:= []
	m_stickDirectionToActionMap := { "Left" : ""
	                               , "Right": ""
	                               , "Up"   : ""
	                               , "Down" : "" }
}

/**
 * Enumerate gamepads available in the system and display brief result in message box:
 * @code{.ahk}
   #incldue <JoyUtil>

   ;Display only joy indices and their OEM names in MsgBox
   while true {
   	joys := JoyEnumerator.enumerateJoys()
   	joyInfoText := ""
   	for ahkJoyIndex, caps in joys {
   		joyInfoText .= ahkJoyIndex "Joy: " quote(caps.oemNameFromRegistry) "`n"
   	}
   	MsgBox 4,, % "Found " joys.Count() " gamepads:`n`n"
   	           . "--------------------------------------`n"
   	           . joyInfoText
   	           . "--------------------------------------`n`n"
   	           . "(Press Yes to reenumerate, press No to exit)"
   	IfMsgBox No
   		return
   }
 * @endcode
 */
class JoyEnumerator extends StaticClassBase {
	joyCount() {
		return DllCall("winmm.dll\joyGetNumDevs")
	}

	enumerateJoys() {
		VarSetCapacity(JOYCAPS, JOYCAPS_sizeof := 728, 0)

		caps := {}
		Loop % JoyEnumerator.joyCount() {
			port := A_Index - 1
			if (error := DllCall("winmm.dll\joyGetDevCaps", "Int",port, "UInt",&JOYCAPS, "UInt",JOYCAPS_sizeof)) {
				continue
			}

			caps[A_Index] :=
			(Join
				{
					wMid: NumGet(JOYCAPS, 0, "UShort"),
					wPid: NumGet(JOYCAPS, 2, "UShort"),
					szPname: StrGet(&JOYCAPS + 4, 32, "UTF-16"),
					wXmin: NumGet(JOYCAPS, 68, "UInt"),
					wXmax: NumGet(JOYCAPS, 72, "UInt"),
					wYmin: NumGet(JOYCAPS, 76, "UInt"),
					wYmax: NumGet(JOYCAPS, 80, "UInt"),
					wZmin: NumGet(JOYCAPS, 84, "UInt"),
					wZmax: NumGet(JOYCAPS, 88, "UInt"),
					wNumButtons: NumGet(JOYCAPS, 92, "UInt"),
					wPeriodMin: NumGet(JOYCAPS, 96, "UInt"),
					wPeriodMax: NumGet(JOYCAPS, 100, "UInt"),
					wRmin: NumGet(JOYCAPS, 104, "UInt"),
					wRmax: NumGet(JOYCAPS, 108, "UInt"),
					wUmin: NumGet(JOYCAPS, 112, "UInt"),
					wUmax: NumGet(JOYCAPS, 116, "UInt"),
					wVmin: NumGet(JOYCAPS, 120, "UInt"),
					wVmax: NumGet(JOYCAPS, 124, "UInt"),
					wCaps: NumGet(JOYCAPS, 128, "UInt"),
					wMaxAxes: NumGet(JOYCAPS, 132, "UInt"),
					wNumAxes: NumGet(JOYCAPS, 136, "UInt"),
					wMaxButtons: NumGet(JOYCAPS, 140, "UInt"),
					szRegKey: StrGet(&JOYCAPS + 144, 32, "UTF-16"),
					szOEMVxD: StrGet(&JOYCAPS + 208, 260, "UTF-16")
				}
			)

			;Calculate additional custom properties for gamepads
			fmt := "{:0 4x}" ;convert to hex with minimum width 4 and prefix with leading zeros if needed
			regVid := Format(fmt, caps[A_Index].wMid)
			regPid := Format(fmt, caps[A_Index].wPid)
			oemName := RegRead("HKEY_CURRENT_USER\System\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_" regVid "&PID_" regPid, "OEMName")
			caps[A_Index, "oemNameFromRegistry"] := oemName
		}
		return caps
	}
}
