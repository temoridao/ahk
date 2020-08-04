/**
 * Description:
 *    Utility functions based on TrayIcon.ahk library
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#include %A_LineFile%\..\Funcs.ahk
#include %A_LineFile%\..\ProcessTerminationWatcher.ahk

#Include %A_LineFile%\..\..\3rdparty\Lib\TrayIcon.ahk

;IMPORTANT: if this doesn't work reliably, try to use #WinActivateForce directive in your script
TrayIconUtils_removeTrayIcons(iconProcessIds, removeAttemptsCount := 3) {
	SetTimer(Func("removeTrayIcons_impl").Bind(iconProcessIds, removeAttemptsCount), "-1", "-100")
} removeTrayIcons_impl(iconProcessIds, attemptsCount) {
	hWnd := WinGet("ID", "A") ;Remember currently active window
	;Force OS to update hidden tray icons by show/hide hidden icons list.
	;Approach #1: ControlClick on taskbar's "^" tray button to unwrap/wrap the menu (ahk_class NotifyIconOverflowWindow):
	ControlClick Button2, ahk_class Shell_TrayWnd,,,2

	;Approach #2: Send Win+B to activate control (inserts unwanted keystroke, may be inappropriate)
	; SendMode Input
	; Send #b{Enter}{Escape}
	; WinWaitActive ahk_class Shell_TrayWnd,,2
	; WinSet Bottom,, ahk_class Shell_TrayWnd
	;Alternative method of activating previous window in the stack:
	; Send !{Escape}

	;Restore previously active window
	WinActivate("ahk_id" hWnd)

	Loop %attemptsCount% { ; Try To Remove Over Time Because Icons May Lag During Bootup
		trayIcons := TrayIcon_GetInfo()
		for i, pid in iconProcessIds {
			for i2, iconData in trayIcons {
				if (pid = iconData.Pid) {
					TrayIcon_Remove(iconData.hWnd, iconData.uID)
					break
				}
			}
		}
		Sleep A_Index**2 * 100
	}
}

; Removes tray icons for non-existent processes which were forcibly closed, crashed, etc
TrayIconUtils_removeOrphans() {
	for i, iconData in TrayIcon_GetInfo() {
		if (!iconData.process) {
			TrayIcon_Remove(iconData.hWnd, iconData.uID)
		}
	}
}

; Hide tray icons which belong to processes with \p pids and
; start tracking of explorer.exe termination/startup to hide tray icons again when this happens
; Returns \c true if explorer.exe successfully started watching or \c false otherwise
TrayIconUtils_ensureTrayIconsHidden(pids) {
	static ptw := new ProcessTerminationWatcher()
	TrayIconUtils_removeTrayIcons(pids, 10)
	; Watch explorer.exe's termination and execute A_ThisFunc when this happens to hide tray icons again.
	; And restart watcher with new PID
	Process Exist, explorer.exe
	return ptw.watch(ErrorLevel, Func(A_ThisFunc).Bind(pids))
}