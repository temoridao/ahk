/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\impl\CallbackStorage.ahk

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

class ShellEventsWatcher extends CallbackStorage {
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

		instance.initCallbacksFromMap(callbacksMap)
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
		if (this.m_isRunning) {
			return
		}

		if (!DllCall("RegisterShellHookWindow", "UInt",A_ScriptHWND)) {
			Throw "Error calling RegisterShellHookWindow(). Ensure you are not creating the second instance of '" this.__Class "'! (RegisterShellHookWindow() supports one HWND per script-process)"
		}

		this.m_msgNum := DllCall("RegisterWindowMessage", "Str","SHELLHOOK")
		this.m_functor := ObjBindMethod(this.base, "shellMessageHandler", &this)
		OnMessage(this.m_msgNum, this.m_functor)

		this.m_isRunning := true
	}

	stop() {
		if (!this.m_isRunning) {
			return
		}

		OnMessage(this.m_msgNum, this.m_functor, 0)
		if (!DllCall("DeregisterShellHookWindow", "UInt", A_ScriptHWND)) {
			Throw "Error calling DeregisterShellHookWindow()"
		}

		this.m_msgNum := 0
		this.m_functor := ""
		this.m_isRunning := false
	}

	isRunning() {
		return this.m_isRunning
	}

	class BlockingWatcher {
		m_isEventReady := false

		__New(WinTitle, timeoutSeconds, WinText, ExcludeTitle, ExcludeText) {
			this.sew := new ShellEventsWatcher
			this.m_eventId := ShellEventsWatcher.HSHELL_WINDOWCREATED
			this.WinTitle := WinTitle
			this.WinText := WinText
			this.ExcludeTitle := ExcludeTitle
			this.ExcludeText := ExcludeText
			this.m_functor := this.onEvent.Bind(this)
			this.sew.addCallback(this.m_eventId, this.m_functor)
			wasRunning := this.sew.isRunning()
			this.sew.start()

			startTime := A_TickCount
			if (timeoutSeconds > 0) {
				while (!this.m_isEventReady) {
					if (timedOut := ((A_TickCount - startTime) / 1000) >= timeoutSeconds) {
						ErrorLevel := "Timeout"
						return ""
					}
					Sleep 50
				}
			} else {
				while (!this.m_isEventReady) {
					Sleep 50
				}
			}
			if (!wasRunning) {
				this.sew.stop() ;TODO: need to implement separate callbacks queue in ShellEventsWatcher for BlockingWatcher usecase, because ShellEventsWatcher is a singletone and using BlockingWatcher interferes now with regular callbacks which may be already registered in ShellEventsWatcher
			}

			ErrorLevel := 0
			return this.m_foundHwnd
		}

		onEvent(hWnd) {
			if (WinExist(this.WinTitle " ahk_id" hWnd, this.WinText, this.ExcludeTitle, this.ExcludeText)) {
				this.m_foundHwnd := hWnd
				this.sew.removeCallback(this.m_eventId, this.m_functor)
				this.m_functor := ""
				this.m_isEventReady := true
			}
		}
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
		this.handleEvent(eventId := wParam, lParam)
	}

	m_msgNum := 0
	m_functor := {}
	m_isRunning := false
}


/**
 * Wait for new window to be created
 *
 * Unlike standard `WinWait` which returns existing window immediately (if it exists at the time of
 * calling the function), the WinWaitNew waits for a brand new window (even if there are
 * already existing windows satisfying requested @p WinTitle criteria).
 *
 * @param   WinTitle        The window title
 * @param   timeoutSeconds  The maximum duration for waiting in seconds. By default it is 0 which
 *                          means infinite duration. `ErrorLevel` will be set to the word "Timeout"
 *                          in case of timeout.
 * @param   WinText         The window text
 * @param   ExcludeTitle    The exclude title
 * @param   ExcludeText     The exclude text
 *
 * @return  Handle (HWND) to the found window or empty value if timed out or some other
 *          error happened
 */
WinWaitNew(WinTitle, timeoutSeconds:=0, WinText:="", ExcludeTitle:="", ExcludeText:="") {
	if (!WinTitle) {
		throw Exception("WinTitle must NOT be empty", A_ThisFunc)
	}
	return new ShellEventsWatcher.BlockingWatcher(WinTitle, timeoutSeconds, WinText, ExcludeTitle, ExcludeText)
}
