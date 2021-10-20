/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\ScriptInfoUtils.ahk

#include %A_LineFile%\..\..\3rdparty\Lib\ProcessInfo.ahk
#include %A_LineFile%\..\..\3rdparty\AutoHotkey-JSON\JSON.ahk

/**
 * Helper class to add serialization support to your own class
 *
 * Example:
 * @code{.ahk}
   #include <Serializable>

   global g_instance := new ExampleSerializableClass()

   OnExit("serializeData") ;Serialize data to .json file upon script exit

   serializeData() {
   	g_instance.serialize()
   }

   class ExampleSerializableClass extends Serializable {
   	m_classData := {"myKey": "myValue"}

   	__New() {
   		Serializable.deserialize(this, this.persistentStateFilename())
   		;OutputDebug % "Deserialized data: " ObjToString(this.m_classData)

   		;Other initialization code...
   	}

   	serialize() {
   		Serializable.serialize(this.persistentStateFilename(), this, "m_classData")
   	}
   }
 * @endcode
*/
class Serializable {
	defaultPersistentStateFileName(fileSubextensionName := "") {
		filePostfix := fileSubextensionName ? ("." fileSubextensionName) : ""
		filePostfix .= ".state.json"

		if (ScriptInfoUtils.isPipedExecution()) {
			return GetModuleFileNameEx(GetCurrentParentProcessID()) . filePostfix
		}

		return A_ScriptFullPath . filePostfix
	}

	persistentStateFilename() {
		return this.defaultPersistentStateFileName(this.__Class)
	}

	allowSavePersistentState() {
		; return !ScriptInfoUtils.isPipedExecution() && !A_IsCompiled
		return true
	}

	/**
	 * Dumps @p dumpFromObj's @p dumpProperties to the @p fileName file
	 *
	 * The @p fileName can later be loaded in __New() method of Serializable subclass to restore state
	 * of the object (see example code in documentation for Serializable class).
	 *
	 * @param   fileName        Path to file where to save JSON
	 * @param   dumpFromObj     The object to dump properties from
	 * @param   dumpProperties  The list of properties to serialize. Leave empty to serialize entire
	 *                          object
	 *
	 * @return  JSON string which was written to @p fileName
	 */
	serialize(fileName, ByRef dumpFromObj, dumpProperties*) {
		if (!Serializable.allowSavePersistentState()) {
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
	;

	/**
	 * Restores state into @p restoreToObj object from @p fileName on disk if it exists
	 *
	 * This function should normally be called from @p restoreToObj's __New() method like this:
	 * @code{.ahk}
	   Serializable.deserialize(this, this.persistentStateFilename())
	 * @endcode
	 *
	 * @param   restoreToObj  The object to restore state to
	 * @param   fileName      The file name which contains JSON dump of @restoreToObj's properties
	 *
	 * @return  @c true on success and @c false if some error occurs
	 */
	deserialize(ByRef restoreToObj, fileName := "") {
		if (!Serializable.allowSavePersistentState()) {
			return false
		}

		fileName := fileName ? fileName : this.defaultPersistentStateFileName()

		for each, property in JSON.Load(FileRead(fileName)) {
			restoreToObj[each] := property
		}
		return true
	}
}