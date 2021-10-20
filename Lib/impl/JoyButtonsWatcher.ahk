/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#NoEnv
#UseHook
#Warn UseUnsetLocal ;, StdOut
#Warn UseUnsetGlobal ;, StdOut
#MaxHotkeysPerInterval 200
#SingleInstance Force
#NoTrayIcon
#Persistent

SetWorkingDir %A_ScriptDir%
SetTitleMatchMode RegEx
SetBatchLines -1
ListLines OFF
FileEncoding UTF-8-RAW

#include %A_LineFile%\..\..\..\3rdparty\Lib\ObjRegisterActive.ahk
#include %A_LineFile%\..\..\TimeIdleCounter.ahk

;{ Config Section
	global gConf :=
	(LTrim Join Comments
	{
		joyIndex: GetCmdParameterValue("--joy-index", 0)

	}
	)
;}

if (gConf.joyIndex = 0) {
	MsgBox % "Missing joystick index cmd parameter"
	ExitApp
}

global gActiveObj := new JoyButtonsActiveObject
ObjRegisterActive(gActiveObj, TimeIdleCounter.GuidJoyKeysWatcherObject)
logDebug("Exposed COM active object with GUID {}: {}", TimeIdleCounter.GuidJoyKeysWatcherObject, gActiveObj)

OnExit("exitFunc")

;
;---------------------------------End of auto-execute section---------------------------------------
;

exitFunc() {
	gActiveObj := "" ;Without explicit assignment the gActiveObj's destructor is not called for some reason
}

class JoyButtonsActiveObject {
	; static OnButtonPress
	subscribeOnButtonPress(clientObj) {
		this.keyWatcher := new JoyKeyWatcher(gConf.joyIndex, clientObj)
	}

	Quit() {
		logDebug("Quit() was called")
		DetectHiddenWindows On  ; WM_CLOSE=0x10
		PostMessage WM_CLOSE:=0x10,,,, ahk_id %A_ScriptHwnd%
		; Now return, so the client's call to Quit() succeeds.
	}
}

class JoyKeyWatcher {
	__New(joyIndex, clientObj) {
		Loop 32 {
			Hotkey(joyIndex "Joy" A_Index, this.processJoyButton.Bind("processJoyButton", &this, A_Index))
		}

		this.joyIndex := joyIndex
		this.clientObj:= clientObj
	}

	__Delete() {
		Loop 32 {
			Hotkey % this.joyIndex "Joy" A_Index, OFF
		}
		; logDebug(Format("'{:s}' [{:#x}] destroyed", this.base.__Class, &this))
	}

;private:
	processJoyButton(thisObjAddress, joyButton) {
		this := Object(thisObjAddress)
		logDebug("joyButton:" joyButton)
		this.clientObj.onJoyButtonPressed(this, joyButton)
	}
}