/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\Funcs.ahk

; Class accepts Func/BoundFunc objects and plain function name as callbacks
; Example usage:
	; #include <WinEventsWatcher>
	; wev := new WinEventsWatcher({(EVENT_OBJECT_DESTROY := 0x8001)  : ["onWinDestroy"]
	;                            , (EVENT_OBJECT_CREATE  := 0x8000)  : ["onWinCreated"]  })
	; wev.addCallback(WinEventsWatcher.EVENT_OBJECT_SHOW, "onWinShow")
	;
	; MsgBox
	;
	; wev.removeCallback(WinEventsWatcher.EVENT_OBJECT_SHOW, "onWinShow")
	;
	; onWinDestroy(winId) {
	; 	DetectHiddenWindows On
	; 	OutputDebug % "Destroyed: " WinGetTitle("ahk_id" winId)
	; }
	; onWinCreated(winId) {
	; 	OutputDebug % "Created: " WinGetTitle("ahk_id" winId)
	; }
	; onWinShow(winId) {
	; 	OutputDebug % "Show: " WinGetTitle("ahk_id" winId)
	; }
class WinEventsWatcher {
;public:

	/** Structure of \p callbacksMap
		{
			eventId1 : ["Callback1", Func("Callback2").Bind(42), ..., Func("CallbackN")],
			eventId2 : [Func("Callback1"), Func("Callback2").Bind(43), ..., "CallbackN"],
			...,
			eventId3 : [Func("Callback1"), Func("Callback2").Bind(44), ..., Func("CallbackN")]
		}
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
;This function's firs0x0t parameter hidden inside implicit "this" variable, we do not use it,
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
	m_callbacksMap := {}
	m_mainCallbackProc := ""
	m_isRunning := false

	/* Event Constants, see https://docs.microsoft.com/en-us/windows/win32/winauto/event-constants
		static EVENT_OBJECT_ACCELERATORCHANGE                := 0x8012
		     , EVENT_OBJECT_CLOAKED                          := 0x8017
		     , EVENT_OBJECT_CONTENTSCROLLED                  := 0x8015
		     , EVENT_OBJECT_CREATE                           := 0x8000
		     , EVENT_OBJECT_DEFACTIONCHANGE                  := 0x8011
		     , EVENT_OBJECT_DESCRIPTIONCHANGE                := 0x800D
		     , EVENT_OBJECT_DESTROY                          := 0x8001
		     , EVENT_OBJECT_DRAGSTART                        := 0x8021
		     , EVENT_OBJECT_DRAGCANCEL                       := 0x8022
		     , EVENT_OBJECT_DRAGCOMPLETE                     := 0x8023
		     , EVENT_OBJECT_DRAGENTER                        := 0x8024
		     , EVENT_OBJECT_DRAGLEAVE                        := 0x8025
		     , EVENT_OBJECT_DRAGDROPPED                      := 0x8026
		     , EVENT_OBJECT_END                              := 0x80FF
		     , EVENT_OBJECT_FOCUS                            := 0x8005
		     , EVENT_OBJECT_HELPCHANGE                       := 0x8010
		     , EVENT_OBJECT_HIDE                             := 0x8003
		     , EVENT_OBJECT_HOSTEDOBJECTSINVALIDATED         := 0x8020
		     , EVENT_OBJECT_IME_HIDE                         := 0x8028
		     , EVENT_OBJECT_IME_SHOW                         := 0x8027
		     , EVENT_OBJECT_IME_CHANGE                       := 0x8029
		     , EVENT_OBJECT_INVOKED                          := 0x8013
		     , EVENT_OBJECT_LIVEREGIONCHANGED                := 0x8019
		     , EVENT_OBJECT_LOCATIONCHANGE                   := 0x800B
		     , EVENT_OBJECT_NAMECHANGE                       := 0x800C
		     , EVENT_OBJECT_PARENTCHANGE                     := 0x800F
		     , EVENT_OBJECT_REORDER                          := 0x8004
		     , EVENT_OBJECT_SELECTION                        := 0x8006
		     , EVENT_OBJECT_SELECTIONADD                     := 0x8007
		     , EVENT_OBJECT_SELECTIONREMOVE                  := 0x8008
		     , EVENT_OBJECT_SELECTIONWITHIN                  := 0x8009
		     , EVENT_OBJECT_SHOW                             := 0x8002
		     , EVENT_OBJECT_STATECHANGE                      := 0x800A
		     , EVENT_OBJECT_TEXTEDIT_CONVERSIONTARGETCHANGED := 0x8030
		     , EVENT_OBJECT_TEXTSELECTIONCHANGED             := 0x8014
		     , EVENT_OBJECT_UNCLOAKED                        := 0x8018
		     , EVENT_OBJECT_VALUECHANGE                      := 0x800E
		     , EVENT_SYSTEM_ALERT                            := 0x0002
		     , EVENT_SYSTEM_ARRANGMENTPREVIEW                := 0x8016
		     , EVENT_SYSTEM_CAPTUREEND                       := 0x0009
		     , EVENT_SYSTEM_CAPTURESTART                     := 0x0008
		     , EVENT_SYSTEM_CONTEXTHELPEND                   := 0x000D
		     , EVENT_SYSTEM_CONTEXTHELPSTART                 := 0x000C
		     , EVENT_SYSTEM_DESKTOPSWITCH                    := 0x0020
		     , EVENT_SYSTEM_DIALOGEND                        := 0x0011
		     , EVENT_SYSTEM_DIALOGSTART                      := 0x0010
		     , EVENT_SYSTEM_DRAGDROPEND                      := 0x000F
		     , EVENT_SYSTEM_DRAGDROPSTART                    := 0x000E
		     , EVENT_SYSTEM_END                              := 0x00FF
		     , EVENT_SYSTEM_FOREGROUND                       := 0x0003
		     , EVENT_SYSTEM_MENUPOPUPEND                     := 0x0007
		     , EVENT_SYSTEM_MENUPOPUPSTART                   := 0x0006
		     , EVENT_SYSTEM_MENUEND                          := 0x0005
		     , EVENT_SYSTEM_MENUSTART                        := 0x0004
		     , EVENT_SYSTEM_MINIMIZEEND                      := 0x0017
		     , EVENT_SYSTEM_MINIMIZESTART                    := 0x0016
		     , EVENT_SYSTEM_MOVESIZEEND                      := 0x000B
		     , EVENT_SYSTEM_MOVESIZESTART                    := 0x000A
		     , EVENT_SYSTEM_SCROLLINGEND                     := 0x0013
		     , EVENT_SYSTEM_SCROLLINGSTART                   := 0x0012
		     , EVENT_SYSTEM_SOUND                            := 0x0001
		     , EVENT_SYSTEM_SWITCHEND                        := 0x0015
		     , EVENT_SYSTEM_SWITCHSTART                      := 0x0014
	*/
}