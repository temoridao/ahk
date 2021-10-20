#include %A_LineFile%\..\..\Funcs.ahk

class CallbackStorage {
	handleEvent(eventId, params*) {
		if (this.m_callbacksMap.HasKey(eventId)) {
			for i, f in this.m_callbacksMap[eventId] {
				f.Call(params*)
			}
		}
	}

	initCallbacksFromMap(callbacksMap := "") {
		for event, callbacksArray in callbacksMap {
			for index, callback in callbacksArray {
				this.addCallback(event, callback)
			}
		}
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
			this.m_callbacksMap[eventId].Push(callback)
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

	hasEvents() {
		return this.m_callbacksMap.Count()
	}

	/* Structure of m_callbacksMap:
		{eventId1 : [Func("Callback1"), Func("Callback2").Bind(42), Func("CallbackN")],
		 eventId2 : [Func("Callback1"), Func("Callback2"), Func("CallbackN").Bind(someData)],
		 ...
		}
	*/
	m_callbacksMap := {}
}