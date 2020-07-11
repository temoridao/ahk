#include %A_LineFile%\..\CommonUtils.ahk

#include %A_LineFile%\..\..\3rdparty\Lib\ProcessInfo.ahk
#include %A_LineFile%\..\..\3rdparty\AutoHotkey-JSON\JSON.ahk

class Serializable {
	defaultPersistentStateFileName(fileSubextensionName := "") {
		filePostfix := fileSubextensionName ? ("." fileSubextensionName) : ""
		filePostfix .= ".state.json"

		if (CommonUtils.isPipedExecution()) {
			return GetModuleFileNameEx(GetCurrentParentProcessID()) . filePostfix
		}

		return A_ScriptFullPath . filePostfix
	}

	persistentStateFilename() {
		return this.defaultPersistentStateFileName(this.__Class)
	}

	; Dumps \p dumpFromObj object's \p dumpProperties to the \p fileName on disk and returns string
	; was written to file. Later this file can be loaded in __New() (for example) to restore state of the object.
	; NOTE about serialization when script exits/reloads: serialize() function may not get access to
	; the props of the object if it is called from its __Delete() function (at least for super-global object instances).
	; As a workaround, call this function from OnExit()-registered handler if you want to save state on script exit/reload
	serialize(fileName, ByRef dumpFromObj, dumpProperties*) {
		if (!CommonUtils.allowSavePersistentState()) {
			return ""
		}

		outputObject := {}
		if dumpProperties.Length() {
			for each, property in dumpProperties {
				val := dumpFromObj[property]
				if (val.Count()) {
					outputObject[property] := val
				}
			}
			if (!outputObject) {
				return ""
			}
		} else {
			outputObject := dumpFromObj ; Dump entire object if no properties selected by the client in dumpProperties*
		}

		fileName := fileName ? fileName : this.defaultPersistentStateFileName()

		stringified := JSON.Dump(outputObject,,4)
		f := FileOpen(fileName, "w")
		f.Write(stringified)
		return stringified
	}

	; Restores state of \p restoreObj AHK object from \p fileName on disk (if exists)
	; This function should normally be called from \p restoreObj __New() method like this:
	;	Serializable.deserialize(this, this.persistentStateFilename())
	deserialize(ByRef restoreToObj, fileName := "") {
		if (!CommonUtils.allowSavePersistentState()) {
			return
		}

		fileName := fileName ? fileName : this.defaultPersistentStateFileName()

		for each, property in JSON.Load(FileRead(fileName)) {
			restoreToObj[each] := property
		}
	}
}