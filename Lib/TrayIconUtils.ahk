/**
 * @file
 *
 * Utility functions based on TrayIcon libary from
 * https://www.autohotkey.com/boards/viewtopic.php?f=6&t=1229
 *
 * @copyright  Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\Funcs.ahk
#include %A_LineFile%\..\ProcessTerminationWatcher.ahk

#Include %A_LineFile%\..\..\3rdparty\Lib\TrayIcon.ahk

;IMPORTANT: if this doesn't work reliably, try to use #WinActivateForce directive in your script

/**
 * Remove tray icons for processes ids passed in @p iconProcessIds
 *
 * @param   iconProcessIds       The array of process identifiers (PID) which must have their tray
 *                               icons hidden. Can be a function object which returns an array
 *                               of the PIDs.
 * @param   removeAttemptsCount  The remove attempts count. Increase if the icons are not hidden in
 *                               some cases.
 */
TrayIconUtils_removeTrayIcons(iconProcessIds, removeAttemptsCount := 3) {
	SetTimer(Func("removeTrayIcons_impl").Bind(IsFunc(iconProcessIds) ? iconProcessIds.Call() : iconProcessIds, removeAttemptsCount), "-1", "-100")
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

;

/**
 * Removes tray icons for non-existent processes which were forcibly closed, crashed, etc
 */
TrayIconUtils_removeOrphans() {
	for i, iconData in TrayIcon_GetInfo() {
		if (!iconData.process) {
			TrayIcon_Remove(iconData.hWnd, iconData.uID)
		}
	}
}

/**
 * Hide tray icons which belong to processes with identifiers passed in @p pids,
 * start tracking of explorer.exe termination/startup to hide tray icons again when this happens
 * (becuase hidden tray icons become visible again on explorer.exe restart)
 * Also monitors WM_DISPLAYCHANGE and hides tray icons when this event fired (on display resolution
 * change and various related cases).
 *
 * @param   pids  The array of process identifiers (PID) which must have their tray icons hidden.
 *                Can be a function object which returns an array of PIDs.
 * @return  @c true if explorer.exe successfully started watching or @c false otherwise
 */
TrayIconUtils_ensureTrayIconsHidden(pids) {
	static ptw := new ProcessTerminationWatcher()
	static funcObjDisplayChange := ""

	TrayIconUtils_removeTrayIcons(pids, 10)

	WM_DISPLAYCHANGE := 0x7e
	if (funcObjDisplayChange) {
		OnMessage(WM_DISPLAYCHANGE, funcObjDisplayChange, 0) ;Unregister msg monitor if it was registered previously
	}
	OnMessage(WM_DISPLAYCHANGE, funcObjDisplayChange := Func("TrayIconUtils_removeTrayIcons").Bind(pids, 5))

	; Watch explorer.exe's termination and execute A_ThisFunc when this happens to hide tray icons again.
	; And restart watcher with new PIDs
	Process Wait, explorer.exe
	return ptw.watch(ErrorLevel, Func(A_ThisFunc).Bind(pids))
}