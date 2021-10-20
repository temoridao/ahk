/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\Funcs.ahk

/**
 * Allows to subscribe for various window system events (activation, creation, closing, etc)
 * and execute user defined callback(s) when these events occur.
 *
 * See SetWinEventHook() function documentation for details:
 * https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwineventhook
 *
 * For available events see: https://docs.microsoft.com/en-us/windows/win32/winauto/event-constants
 *
 * @code{.ahk}
   #include <WinEventsWatcher>

   wev := new WinEventsWatcher({(EVENT_OBJECT_DESTROY := 0x8001)  : ["onWinDestroy"]
                              , (EVENT_OBJECT_CREATE  := 0x8000)  : ["onWinCreated"]  })
   wev.addCallback(WinEventsWatcher.EVENT_OBJECT_SHOW, "onWinShow")

   MsgBox % "Press OK to remove onWinShow callback"

   wev.removeCallback(WinEventsWatcher.EVENT_OBJECT_SHOW, "onWinShow")

   MsgBox
   ExitApp

   onWinDestroy(hWnd) {
   	DetectHiddenWindows On
   	OutputDebug % "Destroyed: " WinGetTitle("ahk_id" hWnd)
   }
   onWinCreated(hWnd) {
   	OutputDebug % "Created: " WinGetTitle("ahk_id" hWnd)
   }
   onWinShow(hWnd) {
   	OutputDebug % "Show: " WinGetTitle("ahk_id" hWnd)
   }
 * @endcode
 *
 * @see ShellEventsWatcher
 */
class WinEventsWatcher {
;public:

	/**
	 * The constructor
	 *
	 * Accepts Func/BoundFunc objects and plain function name as callbacks.
	 * For the list of available event identifiers see
	 * see https://docs.microsoft.com/en-us/windows/win32/winauto/event-constants
	 *
	 * Some typical events demonstrated in code section of this class documentation.
	 *
	 * @param   callbacksMap  The object containing event identifiers and callbacks to execute when
	 *                        these events occur.
	 *                        Structure:
	 *                        {
	 *                          eventId1 : ["func1", Func("Callback2").Bind(42), Func("CallbackN")],
	 *                          eventId2 : [Func("Callback2").Bind(43), "CallbackN"],
	 *                          eventIdN : [Func("Callback1"), Func("CallbackN")]
	 *                        }
	 */
	__New(callbacksMap := "") {
		this.m_mainCallbackProc := RegisterCallback(this.onWinEvent,,,&this)

		for eventId, callbacksArray in callbacksMap {
			for index, callback in callbacksArray {
				this.addCallback(eventId, callback)
			}
		}

		if (callbacksMap) {
			this.start()
		}
	}

	__Delete() {
		; MsgBox % this.__Class " destroying!!!"
		this.stop()
		DllCall("GlobalFree", "Ptr", this.m_mainCallbackProc, "Ptr")
	}

	start() {
		if (this.m_isRunning) {
			return
		}

		this.hookAllEvents()
		this.m_isRunning := true
	}

	stop() {
		if (!this.m_isRunning) {
			return
		}
		this.unhookAllEvents()
		this.m_isRunning := false
	}

	addCallback(eventId, callback) {
		if (!callback) {
			return
		}

		isNewEventId := !this.m_callbacksMap.HasKey(eventId)
		if (isNewEventId) {
			this.m_callbacksMap[eventId] := {}
		}

		callback := IsObject(callback) ? callback : Func(callback)
		if (this.m_callbacksMap[eventId].callbacks.Count()) {
			this.m_callbacksMap[eventId].callbacks.Push(callback)
		} else {
			this.m_callbacksMap[eventId].callbacks := [callback]
		}

		if (isNewEventId && this.m_isRunning) {
			this.setupHookForEvent(eventId)
		}
	}

	removeCallback(eventId := "INVALID_EVENT", callback := "") {
		if (eventId = "INVALID_EVENT") {
			this.clearAllCallbacks()
			return
		}

		if (!this.m_callbacksMap.HasKey(eventId)) {
			return
		}

		hookHandle := this.m_callbacksMap[eventId].hHook
		if (!callback) {
			if (hookHandle) {
				if (!DllCall("user32\UnhookWinEvent", Ptr,hookHandle)) {
					MsgBox % "UnhookWinEvent() failed for eventId: " eventId
				}
				this.m_callbacksMap.Delete(eventId)
			}
			return
		}

		callback := IsObject(callback) ? callback : Func(callback)
		if (index := HasVal(this.m_callbacksMap[eventId].callbacks, callback)) {
			this.m_callbacksMap[eventId].callbacks.removeAt(index)

			if (!this.m_callbacksMap[eventId].callbacks.Count()) {
				if (!DllCall("user32\UnhookWinEvent", Ptr,hookHandle)) {
					MsgBox % "UnhookWinEvent() failed for eventId: " eventId
				}

				this.m_callbacksMap.Delete(eventId)
			}
		}
	}

	isRunning() {
		return this.m_isRunning
	}

;private:
;This function's first parameter hidden inside implicit "this" variable, we do not use it,
;but extract explicitly in comments below for clarity.
;See https://www.autohotkey.com/boards/viewtopic.php?p=235243#p235243 for detailed explanation
	onWinEvent(eventId, hWnd) {
		ListLines Off
		; Extracting the first parameter to "onWinEvent()" passed in implicit "this" variable,
		; so we extract it with "varNameForFirstParameter := this" -> "hWinEventHook := this"
		; hWinEventHook := this

		this := object(A_EventInfo)
		if (this.m_callbacksMap.HasKey(eventId)) {
			for i, callback in this.m_callbacksMap[eventId].callbacks {
				callback.Call(hWnd)
			}
		}
	}

	hookAllEvents() {
		for eventId, v in this.m_callbacksMap {
			this.setupHookForEvent(eventId)
		}
	}

	unhookAllEvents() {
		for eventId, value in this.m_callbacksMap {
			if (!DllCall("user32\UnhookWinEvent", Ptr, value.hHook)) {
				MsgBox % "UnhookWinEvent() failed for eventId: " eventId
			}
		}
	}

	setupHookForEvent(eventId) {
		if (!this.m_callbacksMap.HasKey(eventId)) {
			throw A_ThisFunc ": eventId " eventId " is expected to be in m_callbacksMap!"
		}

		this.m_callbacksMap[eventId].hHook := DllCall("user32\SetWinEventHook", UInt,eventId, UInt,eventId, Ptr,0, Ptr,this.m_mainCallbackProc, UInt,0, UInt,0, UInt,0, Ptr)
		if (!this.m_callbacksMap[eventId].hHook) {
			MsgBox % A_ThisFunc ": Invalid call to SetWinEventHook() for event '" eventId "'"
		}
	}

	clearAllCallbacks() {
		for eventId, value in this.m_callbacksMap {
			this.m_callbacksMap[eventId].callbacks := []
		}
	}

	/* Structure of m_callbacksMap
		{
			eventId1 : { hHook : Ptr(winEventHookHandle1), callbacks : [Func("Callback1"), Func("Callback2").Bind(42), ..., Func("CallbackN")] },
			eventId2 : { hHook : Ptr(winEventHookHandle2), callbacks : [Func("Callback1"), Func("Callback2").Bind(43), ..., Func("CallbackN")] },
			...,
			eventIdN : { hHook : Ptr(winEventHookHandleN), callbacks : [Func("Callback1"), Func("Callback2").Bind(44), ..., Func("CallbackN")] }
		}
	*/
	m_isRunning        := false
	m_callbacksMap     := {}
	m_mainCallbackProc := ""
}