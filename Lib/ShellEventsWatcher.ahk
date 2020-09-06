/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\Funcs.ahk

/**
 * Allows to subscribe for various window events (activation, creation, closing, etc) and execute
 * user defined callback(s) when these events occur
 *
 * See documentation for RegisterShellHookWindow() function:
 * https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registershellhookwindow
 * For available events see
 * https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644991(v%3Dvs.85)
 *
 * ShellEventsWatcher is a singleton due to RegisterShellHookWindow() nature. Multiple variables
 * can be freely created with `new ShellEventsWatcher(...)`, but only single instance will be
 * returned as a result. Class accepts Func/BoundFunc objects and plain function name to be
 * registered as callbacks. The callback will receive 1 parameter - handle (hWnd) to the window
 * causing the event to occur.
 *
 * @code{.ahk}
   #include <ShellEventsWatcher>

   ;Create watcher providing event and callback(s) in constructor and start immediately
   eventWinCreated := ShellEventsWatcher.HSHELL_WINDOWCREATED ;Fires when a top-level window is first created
   watcher := new ShellEventsWatcher({(eventWinCreated) : ["onTopLevelWindowCreated"]})

   ;or alternatively specify events and callback(s) later with @c addCallback():
   ; watcher := new ShellEventsWatcher()
   ; watcher.addCallback(ShellEventsWatcher.HSHELL_WINDOWCREATED, "onTopLevelWindowCreated")
   ; watcher.start()
   ; MsgBox % "Press OK to stop watcher and exit script"
   ; watcher.stop()
   ; ExitApp

   ;--------------------------End of auto-execute section--------------------------

   onTopLevelWindowCreated(hWnd) {
   	;No need to restore previous values of A_TitleMatchMode and A_WinDelay:
   	;this callback executed in context of OnMessage() handler thread and doesn't influence global values
   	SetTitleMatchMode 2 ;Match anywhere
   	SetWinDelay 0       ;Set minimal delay for window operations

   	static blockTheseWinTitles := ["Recycle Bin ahk_exe explorer.exe" ;Block Recycle Bin window, but not other explorer's windows
   	                             , "ahk_exe Skype.exe"]               ;Block all of skype windows
   	;Close just created window if it is inside blacklist
   	id := "ahk_id" hWnd
   	for i, blackListedTitle in blockTheseWinTitles {
   		if (WinExist(blackListedTitle " " id)) {
   			WinClose % id
   		}
   	}

   	;And show message box when opened windows with "This PC" or "File Explorer" title
   	title := WinGetTitle(id " ahk_class CabinetWClass")
   	if (title ~= "This PC|File Explorer") {
   		MsgBox % "You have opened: " title
   	}
   }
 * @endcode
*/
class ShellEventsWatcher {
;public:

	;{ Event Constants [https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644991(v%3Dvs.85)]
		static HSHELL_WINDOWCREATED       := 1
		     , HSHELL_WINDOWDESTROYED     := 2
		     , HSHELL_WINDOWACTIVATED     := 32772 ; MSDN and WinUser.h say HSHELL_WINDOWACTIVATED == 4, but actually it is 32772 for some reason
		     , HSHELL_GETMINRECT          := 5
		     , HSHELL_WINDOWREPLACING     := 14
		     , HSHELL_WINDOWREPLACED      := 13
		     , HSHELL_ACTIVATESHELLWINDOW := 3
		     , HSHELL_TASKMAN             := 7
		     , HSHELL_REDRAW              := 6
		     , HSHELL_RUDEAPPACTIVATED    := ShellEventsWatcher.HSHELL_WINDOWACTIVATED | ShellEventsWatcher.HSHELL_HIGHBIT
		     , HSHELL_FLASH               := ShellEventsWatcher.HSHELL_REDRAW          | ShellEventsWatcher.HSHELL_HIGHBIT
		     , HSHELL_ENDTASK             := 10
		     , HSHELL_APPCOMMAND          := 12
		     , HSHELL_MONITORCHANGED      := 16
		     , HSHELL_HIGHBIT             := 0x8000
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

	/* Structure of m_callbacksMap:
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

