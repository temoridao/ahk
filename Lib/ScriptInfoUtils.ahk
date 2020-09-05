/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\ImmutableClass.ahk

/**
 * Contains utility functions which return various info about script
 */
class ScriptInfoUtils extends ImmutableClass {
	isPipedExecution() {
		return InStr(A_ScriptFullPath, "\.\pipe")
	}

	ShowAhkInfo() {
		MsgBox % "You are running AHK " . A_AhkVersion (A_IsUnicode ? " Unicode" : " ANSI")
		                                . (A_PtrSize = 8 ? " 64" : " 32") . "bit`n`n"
		                                . "Executable: " A_AhkPath "`n`n"
		                                . "Running through pipe: " !!ScriptInfoUtils.isPipedExecution()
	}

}