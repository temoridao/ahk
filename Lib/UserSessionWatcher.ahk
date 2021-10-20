/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\impl\CallbackStorage.ahk
#include %A_LineFile%\..\ErrMsg.ahk

/**
 * Subscribe to user session events and execute callbacks
 *
 * See docs about WM_WTSSESSION_CHANGE event for details.
 *
 * @code{.ahk}
   #include <UserSessionWatcher>
   #include <LogUitls> ;for logDebug()

   #Persistent

   global usw := new UserSessionWatcher()
   usw.addCallback(UserSessionWatcher.WTS_SESSION_LOCK,   Func("logDebug").Bind("session locked!"))
   usw.addCallback(UserSessionWatcher.WTS_SESSION_UNLOCK, Func("logDebug").Bind("session unlocked!"))
   usw.start()
 * @endcode
 */
class UserSessionWatcher extends CallbackStorage {
	;{ Event Constants
		static WTS_CONSOLE_CONNECT := 0x1
	       , WTS_CONSOLE_DISCONNECT := 0x2
	       , WTS_REMOTE_CONNECT := 0x3
	       , WTS_REMOTE_DISCONNECT := 0x4
	       , WTS_SESSION_LOGON := 0x5
	       , WTS_SESSION_LOGOFF := 0x6
	       , WTS_SESSION_LOCK := 0x7
	       , WTS_SESSION_UNLOCK := 0x8
	       , WTS_SESSION_REMOTE_CONTROL := 0x9
	       , WTS_SESSION_CREATE := 0xA
	       , WTS_SESSION_TERMINATE := 0xB
	;}

	__New(callbacksMap := "") {
		static isSubscribedToNotification := false
		if (!isSubscribedToNotification) {
			if (DllCall("Wtsapi32.dll\WTSRegisterSessionNotification", "Uint",A_ScriptHwnd, "Uint",NOTIFY_FOR_THIS_SESSION:=0, "uint")) {
				OnExit(Func("DllCall").Bind("Wtsapi32.dll\WTSUnRegisterSessionNotification", "Uint",A_ScriptHwnd))
				isSubscribedToNotification := true
			} else {
				MsgBox % "Failed call to WTSRegisterSessionNotification: " ErrMsg()
			}
		}

		this.initCallbacksFromMap(callbacksMap)
		if (callbacksMap) {
			this.start()
		}
		return this
	}

	__Delete() {
		this.stop()
		; MsgBox % this.__Class  "("&this ") deleted!"
	}

	start() {
		if (this.m_isRunning) {
			return
		}

		OnMessage(WM_WTSSESSION_CHANGE := 0x2b1, this.m_functor := ObjBindMethod(this.base, "messageHandler", &this))
		this.m_isRunning := true
	}

	stop() {
		if (!this.m_isRunning) {
			return
		}

		OnMessage(WM_WTSSESSION_CHANGE := 0x2b1, this.m_functor, 0)
		this.m_functor := ""
		this.m_isRunning := false
	}

	isRunning() {
		return this.m_running
	}

;private:
	messageHandler(ahkThisObjAddress, wParam, lParam) {
		this := object(ahkThisObjAddress)
		sessionId := lParam
		this.handleEvent(eventId := wParam)
	}

	m_running := false
}