/**
 * Description:
 *    %TODO%
 *    ShellEventsWatcher is a singletone due to RegisterShellHookWindow() nature.
 *    Multiple variables can be freely created with `new ShellEventsWatcher(...)`, but only single
 *    instance will be returned as a result.
 *    Class accepts Func/BoundFunc objects and plain function name as callbacks
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#include %A_LineFile%\..\Funcs.ahk

; TODO: document class usage and methods.
class ShellEventsWatcher {
;public:

	;{ Event Constants (https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644991(v%3Dvs.85))
		static HSHELL_WINDOWCREATED := 1
		     , HSHELL_WINDOWDESTROYED := 2
		     , HSHELL_WINDOWACTIVATED := 32772 ; MSDN and WinUser.h say HSHELL_WINDOWACTIVATED == 4, but actually it is 32772 for some reason
		     , HSHELL_GETMINRECT := 5
		     , HSHELL_WINDOWREPLACING := 14
		     , HSHELL_WINDOWREPLACED := 13
		     , HSHELL_ACTIVATESHELLWINDOW := 3
		     , HSHELL_TASKMAN := 7
		     , HSHELL_REDRAW := 6
		     , HSHELL_RUDEAPPACTIVATED := ShellEventsWatcher.HSHELL_WINDOWACTIVATED|ShellEventsWatcher.HSHELL_HIGHBIT
		     , HSHELL_FLASH := ShellEventsWatcher.HSHELL_REDRAW|ShellEventsWatcher.HSHELL_HIGHBIT
		     , HSHELL_ENDTASK := 10
		     , HSHELL_APPCOMMAND := 12
		     , HSHELL_MONITORCHANGED := 16
		     , HSHELL_HIGHBIT := 0x8000
	;}

	__New(callbacksMap := "") {
		static instance := ""

		if (!instance) {
			instance := this
		}

		for event, callbacksArray in callbacksMap {
			for index, callback in callbacksArray {
				instance.addCallback(event, callback)
			}
		}

		if (callbacksMap) {
			instance.start()
		}

		return instance
	}

	__Delete() {
		this.stop()
		; MsgBox % this.__Class  "("&this ") deleted!"
	}

	start() {
		if (this.m_running) {
			return
		}

		if (!DllCall("RegisterShellHookWindow", "UInt",A_ScriptHWND)) {
			Throw "Error calling RegisterShellHookWindow(). Ensure you are not creating the second instance of '" this.__Class "'! (RegisterShellHookWindow() supports one HWND per script-process)"
		}

		this.m_msgNum := DllCall("RegisterWindowMessage", "Str","SHELLHOOK")
		this.m_functor := ObjBindMethod(this.base, "shellMessageHandler", &this)
		OnMessage(this.m_msgNum, this.m_functor)

		this.m_running := true
	}

	stop() {
		if (!this.m_running) {
			return
		}

		OnMessage(this.m_msgNum, this.m_functor, 0)
		if (!DllCall("DeregisterShellHookWindow", "UInt", A_ScriptHWND)) {
			Throw "Error calling DeregisterShellHookWindow()"
		}

		this.m_msgNum := 0
		this.m_functor := ""
		this.m_running := false
	}

	isRunning() {
		return this.m_running
	}

	addCallback(eventId, callback) {
		if (!callback) {
			return
		}

		; If callback is not an object (f.e. string containing name of the function), wrap it with Func() object
		callback := IsObject(callback) ? callback : Func(callback)

		if (!this.m_callbacksMap[eventId].Count()) {
			this.m_callbacksMap[eventId] := [callback]
		} else {
			this.m_callbacksMap[eventId].insertAt(this.m_callbacksMap[eventId].MaxIndex() + 1, callback)
		}
	}

	removeCallback(eventId, callback := "") {
		if (!callback) {
			this.m_callbacksMap.Delete(eventId)
			return
		}

		callback := IsObject(callback) ? callback : Func(callback)
		if (index := HasVal(this.m_callbacksMap[eventId], callback)) {
			this.m_callbacksMap[eventId].removeAt(index)
		}
	}

	clearCallbacks() {
		this.m_callbacksMap := {}
	}

;private:
	shellMessageHandler(ahkThisObjAddress, wParam, lParam) {
		ListLines Off
		; OutputDebug % "wParam: " wParam
		this := object(ahkThisObjAddress)

		; if (wParam = ShellEventsWatcher.HSHELL_WINDOWCREATED) {
			; OutputDebug % "Created Window: "  WinGetTitle("ahk_id" lParam)
		; } else if (wParam = ShellEventsWatcher.HSHELL_WINDOWACTIVATED || wParam = 4) {
			; OutputDebug % "Activated Window: " WinGetTitle("ahk_id" lParam)
		; }

		if (this.m_callbacksMap.HasKey(wParam)) {
			for i, f in this.m_callbacksMap[wParam] {
				f.Call(lParam)
			}
		}
	}

	/* Structure of ShellEventsWatcher.m_callbacksMap:
		{eventId1 : [Func("Callback1"), Func("Callback2").Bind(42), Func("CallbackN")],
		 eventId2 : [Func("Callback1"), Func("Callback2"), Func("CallbackN").Bind(someData)],
		 ...
		}
	*/
	m_callbacksMap := {}

	m_msgNum := 0
	m_functor := {}
	m_running := false
}

