;Dictionary object with ordered keys
;https://www.autohotkey.com/boards/viewtopic.php?p=310596&sid=6bb849262626465502baa854046d55e9#p310596
class ScriptingDictionary
{
	__New(initContent := "") {
		this._dict_ := ComObjCreate("Scripting.Dictionary")

		if (initContent) {
			for k, v in initContent {
				this[k] := v
			}
		}
	}

	__Call(methodName, args*) {
		if (methodName == "Length" || methodName == "Count") {
			return this._dict_.Count
		}
	}

	__Delete() {
		this._dict_.RemoveAll()
		this.SetCapacity("_dict_", 0)
		this._dict_ := ""
	}

	__Set(key, value) {
		if (key != "_dict_") {
			return this._dict_.Item(key) := value
		}
	}

	__Get(key) {
		if (key == "_dict_")
			Return
		if (key == "Keys" || key == "Items") {
			keys := this._dict_[key]
			arr := []
			Loop % this._dict_.Count
				arr.Push(keys[A_Index - 1])
			Return arr
		}

		Return this._dict_.Item(key)
	}

	_NewEnum() {
		Return new ScriptingDictionary._CustomEnum_(this._dict_)
	}

	class _CustomEnum_
	{
		__New(dict) {
			this.i := -1
			this.dict := dict
			this.keys := this.dict.Keys()
			this.items := this.dict.Items()
		}

		Next(ByRef k, ByRef v) {
			if ( ++this.i = this.dict.Count() )
				Return false
			k := this.keys[this.i]
			v := this.items[this.i]
			Return true
		}
	}

	Delete(key) {
		if this._dict_.Exists(key) {
			value := this._dict_.Item(key)
			this._dict_.Remove(key)
		}
		Return value
	}

	HasKey(key) {
		Return !!this._dict_.Exists(key)
	}
}
