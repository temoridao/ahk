/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\Funcs.ahk

/**
 * Provides interface to store/retrieve script configuration parameters in the .ini files
 *
 * This is essentially a wrapper around `IniRead`, `IniWrite`, `IniDelete` commands which are used
 * under the hood to store/retrieve configuration parameters.
 * By default config file for the script located at
 * `%A_AppData%\AutoHotkey\%A_ScriptName%\config.ini` and crated by constructor
 * of @ref ScriptIniConfig if it doesn't exist (this can be overridden by @p create parameter).
 *
 * @code{.ahk}
   global g_scriptConfig := new ScriptIniConfig
   joyMode := "xinput"
   joyNumber := 3

   ;Save variables into config file
   g_scriptConfig.write(joyMode, "joy", "mode")
   g_scriptConfig.write(joyNumber, "joy", "number")
   MsgBox % "Values written: " joyMode " " joyNumber

   ;Retrieve previously saved variables
   storedJoyMode := g_scriptConfig.read("joy", "mode")
   storedJoyNumber := g_scriptConfig.read("joy", "number")
   MsgBox % "Values read: " storedJoyMode " " storedJoyNumber
 * @endcode
 */
class ScriptIniConfig {
	/**
	 * @param   scriptName  The script's file name for which to create this @ref ScriptIniConfig
	 *                      instance. Defaults to `A_ScriptName`
	 * @param   create      Create config file if it doesn't exist. If @p scriptName is not empty and
	 *                      not equal to value of `A_ScriptName`, this parameter has no effect,
	 *                      i.e. this constructor creates @ref ScriptIniConfig providing read-only
	 *                      interface for non-own configuration files
	 */
	__New(scriptName := "", create := true) {
		if (isPipedExecution := InStr(A_ScriptFullPath, "\.\pipe")) {
			logWarn("Skip config creation for script executed from named pipe")
			return ""
		}
		filePath := this.getConfigPathForScript(scriptName)
		if (!filePath) {
			MsgBox Config file cannot be created
			return
		}

		ownConfigFileRequested := !scriptName || scriptName = A_ScriptName
		if (ownConfigFileRequested && create && !FileExist(filePath)) {
			SplitPath(filePath,,OutDir), FileCreateDir(OutDir), FileAppend("", filePath)
		}
		this.m_filePath := filePath
	}

	read(Section, Key, Default := "") {
		return IniRead(this.m_filePath, Section, Key, Default ? Default : A_Space)
	}
	write(Value, Section, Key := "") {
		IniWrite(Value, this.m_filePath, Section, Key)
	}
	delete(Section, Key := "") {
		IniDelete(this.m_filePath, Section, Key)
	}

	filePath() {
		return this.m_filePath
	}
	exist() {
		return FileExist(this.m_filePath) ? true : false
	}

;private
	getConfigPathForScript(scriptName) {
		if (A_IsCompiled) {
			return A_ScriptFullPath ".ini"
		} else {
			;A_ScriptFullPath not exist while script running through named pipe.
			;Accessing/creating config files is prohibited in this case
			baseDir := FileExist(A_ScriptFullPath) ? (A_AppData "\AutoHotkey\" (scriptName ? scriptName : A_ScriptName))
			                                       : ""
			return baseDir ? (baseDir "\config.ini") : ""
		}
	}
}