/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

;Hooks required for accuracy of A_TimeIdlePhysical
#InstallKeybdHook
#InstallMouseHook

#include %A_LineFile%\..\JoyUtil.ahk

class TimeIdleCounter {
	__New() {
		lStickValues := ""
		rStickValues := ""
		watchForJoyKeys := true
		;LS and RS providers should be BOTH valid or BOTH invalid and deal with the same joystick
		;(in case of they are both valid). Otherwise throw exception
		if ((lStickValues && !rStickValues) || (!lStickValues && rStickValues)
		|| (lStickValues && rStickValues &&  (lStickValues.JoyIndex != rStickValues.JoyIndex))) {
			throwException("Different joysticks indices for left and right stick are not supported "
				           . "within single instance of " this.__Class " class")
		}

		if (lStickValues.JoyIndex && watchForJoyKeys) {
			if (!A_IsCompiled) {
				cmdLine := Format("{} {} --joy-index {}", A_AhkPath, quote(A_LineFile "\..\impl\JoyButtonsWatcher.ahk")
				                                                   , lStickValues.JoyIndex)
				this.watcherPid := Run(cmdLine)
				Sleep 500 ;Take time for COM object's exposition by new script
				this.keysWatcherActiveObj := ComObjActive(TimeIdleCounter.GuidJoyKeysWatcherObject)
				this.keysWatcherActiveObj.subscribeOnButtonPress(this)
			}
		}

		this.trackingTable := {}
		this.lStickValues := lStickValues
		this.rStickValues := rStickValues
		this.joystickIdleTime := 0
		this.watchForJoyKeys := watchForJoyKeys
		this.m_functorAxesPoll := this.pollJoystickAxesAndPOV.Bind("pollJoystickAxesAndPOV", &this)
		SetTimer(this.m_functorAxesPoll, this.joyAxesPollInterval)

		this.m_functorIdleTracking := this.idleTimeChecker.Bind("idleTimeChecker", &this)
		SetTimer(this.m_functorIdleTracking, this.atimeIdlePollInterval)
	}

	__Delete() {
		if (this.keysWatcherActiveObj) {
			this.keysWatcherActiveObj.Quit()
		}

		SetTimer(this.m_functorIdleTracking, "Delete")
		SetTimer(this.m_functorAxesPoll, "Delete")
		; OutputDebug % Format("'{:s}' [{:#x}] destroyed", this.base.__Class, &this)
	}

	TimeIdlePhysical[id := ""] {
		get {
			id := id ? id : TimeIdleCounter.DefaultTrackingId
			return this.trackingTable.HasKey(id) ? this.trackingTable[id].idleTime : 0
		}
		set {
		}
	}

	start(timeout := "", onTimeout := "", id := "") {
		id := id ? id : TimeIdleCounter.DefaultTrackingId
		this.trackingTable[id] := { enabled: true
			                        , lastJoyValue: this.joystickIdleTime
			                        , lastPhysicalValue: A_TimeIdlePhysical
			                        , idleTime: 0
			                        , timeout: Abs(timeout)
			                        , onTimeout: (IsObject(onTimeout) ? onTimeout : Func(onTimeout)) }
	}

	/**
	 * Similar to @ref start(), but preserve tracking parameters (e.g. timeout,
	 * onTimeout callback, etc) which were set on prevoius @ref start() call
	 *
	 * @return  `true` on success, `false` if @p id not found
	 */
	restart(id := "") {
		id := id ? id : TimeIdleCounter.DefaultTrackingId
		if (!this.trackingTable.HasKey(id)) {
			return false
		}

		data := this.trackingTable[id]
		data.lastJoyValue := this.joystickIdleTime
		data.lastPhysicalValue := A_TimeIdlePhysical
		data.idleTime := 0
		data.enabled := true
		return true
	}

	stop(id := "") {
		id := id ? id : TimeIdleCounter.DefaultTrackingId
		this.trackingTable[id].enabled := false
	}

	active(id := "") {
		id := id ? id : TimeIdleCounter.DefaultTrackingId
		if (!this.trackingTable.HasKey(id)) {
			return false
		}
		return this.trackingTable[id].enabled
	}

	autoRestart() {
		return this.m_autoRestart
	}
	setAutoRestart(autoRestart) {
		this.m_autoRestart := autoRestart
	}

;private:
	m_autoRestart := true
	joyAxesPollInterval := 250
	atimeIdlePollInterval := 1000

	joyValid() {
		return !!this.lStickValues && !!this.rStickValues && JoyUtil.isConnected(this.lStickValues.JoyIndex)
	}

	idleTimeChecker(objAddress) {
		this := Object(objAddress)
		for id, data in this.trackingTable {
			if (!data.enabled) {
				continue
			}
			currentAtime := A_TimeIdlePhysical
			if (this.inputDeviceTouched(id, currentAtime)) {
				data.idleTime := 0
			} else {
				data.idleTime += this.atimeIdlePollInterval
			}
			data.lastJoyValue := this.joystickIdleTime
			data.lastPhysicalValue := currentAtime

			if (data.timeout && data.onTimeout && (data.idleTime >= data.timeout)) {
				this.stop(id)
				data.onTimeout.Call()
				if (this.m_autoRestart) {
					this.restart(id)
				}
			}
		}
	}

	inputDeviceTouched(id, aTimeStamp) {
		if (!this.trackingTable.HasKey(id)) {
			return false
		}

		kbOrMouseTouched := aTimeStamp <= this.trackingTable[id].lastPhysicalValue
		joyTouched := this.joystickIdleTime <= this.trackingTable[id].lastJoyValue
		return kbOrMouseTouched || (this.joyValid() && joyTouched)
	}

	pollJoystickAxesAndPOV(objAddress) {
		this := object(objAddress)
		if (!this.joyValid()) {
			this.joystickIdleTime += this.joyAxesPollInterval
			return
		}

;@Ahk2Exe-IgnoreBegin
		if (((this.lStickValues.Direction != "xyCentered") || (this.rStickValues.Direction != "xyCentered"))
			                                                 || JoyUtil.povDirection(this.lStickValues.JoyIndex)) {
;@Ahk2Exe-IgnoreEnd
/*@Ahk2Exe-Keep
		;In case of compiled version fall back to loop over 32 possible joy buttons because it is not
		;always possible to spawn new AutoHotkey process in a portable environment
		if (((this.lStickValues.Direction != "xyCentered") || (this.rStickValues.Direction != "xyCentered"))
		                                                   || JoyUtil.povDirection(this.lStickValues.JoyIndex)
		                                                   || (this.watchForJoyKeys() && this.checkJoyButtonsPress())) {
*/
			this.joystickIdleTime := 0
		} else {
			this.joystickIdleTime += this.joyAxesPollInterval
		}
	}
/*@Ahk2Exe-Keep
	checkJoyButtonsPress() {
		Loop 32 {
			if (GetKeyState(this.lStickValues.JoyIndex "Joy" A_Index, "P")) {
				return true
			}
		}
		return false
	}
*/
	onJoyButtonPressed(worker, buttonId) {
		logDebug("buttonId:", buttonId)
		this.joystickIdleTime := 0
	}

	static GuidJoyKeysWatcherObject := "{17B10101-2141-4331-BAAF-062D880D6777}"
	     , DefaultTrackingId := "Default Tracking Id {E5D12166-0C42-4A5B-94F0-2F3C6A2EB960}"
}
