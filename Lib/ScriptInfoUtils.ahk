/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\AhkScriptController.ahk
#include %A_LineFile%\..\LogUtils.ahk

/**
 * Contains utility functions which return various info about script
 */
class ScriptInfoUtils extends StaticClassBase {
	isPipedExecution() {
		return InStr(A_ScriptFullPath, "\.\pipe")
	}

	ShowAhkInfo() {
		MsgBox % "You are running AHK " . A_AhkVersion (A_IsUnicode ? " Unicode" : " ANSI")
		                                . (A_PtrSize = 8 ? " 64" : " 32") . "bit`n`n"
		                                . "Executable: " A_AhkPath "`n`n"
		                                . "Running through pipe: " !!ScriptInfoUtils.isPipedExecution()
	}

	/**
	 * If this script already has running instances - stop them
	 *
	 * Requires `#SingleInstance OFF` for script which uses this function
	 */
	stopScriptOtherIstances() {
		logDebug("About to stop running instance(s) of this script")
		if (A_IsCompiled) {
			wmi := ComObjGet("winmgmts:")
			queryEnum := wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name=""" A_ScriptName """")._NewEnum()
			proc := ""
			while (queryEnum[proc]) {
				logDebug("Terminating process (" proc.ProcessId ")")
				Process Close, % proc.ProcessId
				; Run %A_ComSpec% /c taskkill /f /fi "IMAGENAME eq %A_ScriptName%"
			}
			return
		}

		raii := new AVarValuesRollback("A_DetectHiddenWindows=ON")
		thisScriptInstances := WinGet("List", A_ScriptName " ahk_class AutoHotkey")

		myPid := DllCall("GetCurrentProcessId")
		for i, hWnd in thisScriptInstances {
			winTitle := "ahk_id" hWnd
			pid := WinGet("PID", winTitle)
			if (pid = myPid) {
				continue
			}

			logDebug("Stop instance (" pid ")")
			AhkScriptController.sendCommand(winTitle, AhkScriptController.ID_FILE_EXIT)
			WinWaitClose % winTitle,,5
			logDebug("Stopped instance (" pid ")")
		}
	}

	/**
	 * @return  PID of first already running instance of calling script or zero if no other
	 *          instances exist
	 */
	checkForExistingInstance() {
		myPid := DllCall("GetCurrentProcessId")
		otherPid := 0
		for i, hWnd in WinGet("List", A_ScriptName " ahk_class AutoHotkey") {
			pid := WinGet("PID", "ahk_id" hWnd)
			if (pid != myPid) {
				otherPid := pid
				break
			}
		}
		return otherPid
	}
}
