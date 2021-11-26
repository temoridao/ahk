/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\AVarValuesRollback.ahk
#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

/**
 * Allows to send command to any running script
 *
 * Example commands are "Exit", "Pause", "Edit", etc.
 *
 * There are number of convenience methods such as setPause(), setSuspend() as well as function to
 * send arbitrary command: sendCommand(). Possible commands defineds as static consts in the body of
 * class and start with `ID_`
 *
 * Class determines info about script by inspecting state of its standard main window's menu items.
 * This means that if a target script has custom main window, the AhkScriptController cannot work as
 * expected
 *
 * @note    This class uses current A_TitleMatchMode
 * @note    This class is Singletone (all methods are static, you don't need to create instance of
 *          AhkScriptController to call its methods)
 */
class AhkScriptController extends StaticClassBase
{
;public:
	toggleSuspend(winTitle) {
		for each, title in this.resolveWinTitle(winTitle) {
			PostMessage AhkScriptController.WM_COMMAND, AhkScriptController.ID_FILE_SUSPEND,,, % title
		}
	}
	isSuspended(winTitle) {
		return this.ahkWinIsSuspended(WinGet("ID", winTitle))
	}
	setSuspend(winTitle, newState) {
		for each, title in this.resolveWinTitle(winTitle) {
			currentState := this.ahkWinIsSuspended(WinGet("ID", title))
			if (currentState != newState) {
				this.toggleSuspend(title)
			}
		}
	}

	setPause(winTitle, newState) {
		for each, title in this.resolveWinTitle(winTitle) {
			currentState := this.ahkWinIsPaused(WinGet("ID", title))
			if (currentState != newState) {
				this.togglePause(title)
			}
		}
	}
	togglePause(winTitle) {
		for each, title in this.resolveWinTitle(winTitle) {
			PostMessage AhkScriptController.WM_COMMAND, AhkScriptController.ID_FILE_PAUSE,,, % title
		}
	}

	sendCommand(winTitle, AHK_SCRIPT_COMMAND) {
		for each, title in this.resolveWinTitle(winTitle) {
			PostMessage, AhkScriptController.WM_COMMAND, AHK_SCRIPT_COMMAND,,, % title
		}
	}

	/**
	 * Send exit command to other script processes and optionally wait for their closing
	 *
	 * @param   externalScriptsPids      List of PIDs (or single value) for scripts that must exit
	 * @param   reverseOrder             If @c true then scripts in @p externalScriptsPids will be
	 *                                   processed in reverse order
	 * @param   waitCloseTimeoutSeconds  The timeout to wait for scripts exiting. If zero, then no
	 *                                   waiting at all performed
	 *
	 * @return  Array of window titles of the scripts which were not exited correctly i.e. returned
	 *          array will be empty if no errors occur
	 */
	exitExternalScripts(externalScriptsPids, reverseOrder := false, waitCloseTimeoutSeconds := 2) {
		raii := avarguard("A_DetectHiddenWindows=ON")

		if (!IsObject(externalScriptsPids)) { ;If only single digit was passed as parameter, create array from it
			externalScriptsPids := [externalScriptsPids]
		}

		len := externalScriptsPids.Length()
		Loop % len {
			i := reverseOrder ? (len - A_Index + 1) : A_Index
			AhkScriptController.sendCommand("ahk_pid" externalScriptsPids[i], AhkScriptController.ID_FILE_EXIT)
		}

		errorScripts := []
		if (waitCloseTimeoutSeconds = 0) {
			return errorScripts
		}

		Loop % len {
			i := reverseOrder ? (len - A_Index + 1) : A_Index
			WinWaitClose % "ahk_pid" externalScriptsPids[i],, %waitCloseTimeoutSeconds%
			if (ErrorLevel) {
				errorScripts.Push(WinGetTitle("ahk_pid" externalScriptsPids[i]))
			}
		}

		return errorScripts
	}

;private:
	/**
	 * This simple proxy class transparently wraps AhkScriptController and sets A_DetectHiddenWindows
	 * to ON before any wrapped class method call and restores variable value back (thanks to
	 * AVarValuesRollback). This approach eliminates code duplication for each method.
	 */
	class ProxyWrapper {
		__New(objectToBeProxied) {
			ObjRawSet(this, "ProxyWrapper", objectToBeProxied)
		}

		__Call(methodName, params*) {
			raii := new AVarValuesRollback("A_DetectHiddenWindows=ON")
			; OutputDebug % "calling: " methodName " A_DetectHiddenWindows:" A_DetectHiddenWindows
			return this["ProxyWrapper"][methodName](params*) ; forward the method call to the wrapped object
		}
	}

	/** The idea of this __New() constructor generalized in @ref SuperGlobalSingleton.ahk */
	__New() {
		if (AhkScriptController.__selfInitInstance) {
			return AhkScriptController.__selfInitInstance
		}

		classPath := StrSplit(this.base.__Class, ".")
		; msgbox % ObjToString(classPath)
		className := classPath.removeAt(1)
		; msgbox % className
		if (classPath.Length() > 0) {
			%className%[classPath*] := new AhkScriptController.ProxyWrapper(this)
		} else {
			%className% := new AhkScriptController.ProxyWrapper(this)
		}
	}
	/*
	 ;NOTE: the next __New() method alsoe works, but client code needs to "create" instance object
	 ;every time it uses class, f.e. 't := new AhkScriptController(), t.method1()',
	 ;so less convenient than __New() above.
	 __New() {
	 	static instance := ""

	 	if (!instance) {
	 		instance := new ProxyWrapper(this)
	 	}

	 	return instance
	 }
	 */

	ahkWinIsSuspended(hWnd) {
		return WinExist("ahk_class AutoHotkey ahk_id" hWnd) ? this.ahkWinGetMenuState(AhkScriptController.ID_FILE_SUSPEND, hWnd) : 0
	}

	ahkWinIsPaused(hWnd) {
		return return WinExist("ahk_class AutoHotkey ahk_id" hWnd) ? this.ahkWinGetMenuState(AhkScriptController.ID_FILE_PAUSE, hWnd) : 0
	}

	ahkWinGetMenuState(ahkWindowMenuId, hWnd) {
		; Working method by Lexikos (https://stackoverflow.com/a/18204526):

		; Get the menu bar.
		mainMenu := DllCall("GetMenu", "ptr", hWnd)
		; Get the File menu.
		fileMenu := DllCall("GetSubMenu", "ptr", mainMenu, "int", 0)
		; Get the state of the menu item.
		state := DllCall("GetMenuState", "ptr", fileMenu, "uint", ahkWindowMenuId, "uint", 0)
		; Get the checkmark flag.
		isMenuItemChecked := state & 0x8 ; MF_CHECKED
		; Clean up.
		DllCall("CloseHandle", "ptr", fileMenu)
		DllCall("CloseHandle", "ptr", mainMenu)

		return isMenuItemChecked

		; Buggy method (periodically freezes script's event loop) which can be found on forums:

		; SendMessage, 0x211,,,, % "ahk_id " hWnd ;WM_ENTERMENULOOP := 0x211
		; SendMessage, 0x212,,,, % "ahk_id " hWnd ;WM_EXITMENULOOP := 0x212
		; hMenu := DllCall("GetMenu", "Ptr",hWnd, "Ptr")
		; MenuState := DllCall("GetMenuState", "Ptr",hMenu, "UInt",ahkWindowMenuId, "UInt",0)
		; Return !!(MenuState & 0x8) ; MF_CHECKED
	}

	; This function makes sure that PostMessage will send message for AutoHotkey window and no one else
	resolveWinTitle(winTitle) {
		result := []
		for each, hWnd in WinGet("List", winTitle) {
			if (AhkScriptController.IgnoreCurrentScript && (hWnd = A_ScriptHwnd)) {
				continue
			}

			if (WinExist(ahkWin := "ahk_id" hWnd " ahk_class AutoHotkey")) {
				result.Push(ahkWin)
			}
		}
		return result
	}

	static IgnoreCurrentScript := false

	static __selfInitInstance := new AhkScriptController.ProxyWrapper(new AhkScriptController())
	static WM_COMMAND := 0x111
	; AHK main window menu id list; source: https://www.autohotkey.com/boards/viewtopic.php?p=130390&sid=01258c2cea1ba45d58ae36d5488b51d8#p130390
	static ID_TRAY_OPEN         := 65300
		   , ID_FILE_RELOADSCRIPT := 65400, ID_TRAY_RELOADSCRIPT := 65303
		   , ID_FILE_EDITSCRIPT   := 65401, ID_TRAY_EDITSCRIPT := 65304
		   , ID_FILE_WINDOWSPY    := 65402, ID_TRAY_WINDOWSPY := 65302
		   , ID_FILE_PAUSE        := 65403, ID_TRAY_PAUSE := 65306
		   , ID_FILE_SUSPEND      := 65404, ID_TRAY_SUSPEND := 65305
		   , ID_FILE_EXIT         := 65405, ID_TRAY_EXIT := 65307
		   , ID_VIEW_LINES        := 65406
		   , ID_VIEW_VARIABLES    := 65407
		   , ID_VIEW_HOTKEYS      := 65408
		   , ID_VIEW_KEYHISTORY   := 65409
		   , ID_VIEW_REFRESH      := 65410
		   , ID_HELP_USERMANUAL   := 65411 ;ID_TRAY_HELP := 65301
		   , ID_HELP_WEBSITE      := 65412
}