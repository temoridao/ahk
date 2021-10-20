/**
 * Description:
 *    Show info about curent icons in the tray menu
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#NoEnv
#Warn UseUnsetLocal
#Warn UseUnsetGlobal
#MaxHotkeysPerInterval 200
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
SetBatchLines -1
SendMode Input
;-------------------------------------------------------------------------------

;{ Config Section
	Gui New, +hWndg_listViewHwnd
;}

#include %A_LineFile%\..\3rdparty\Lib\TrayIcon.ahk

Gui Add, ListView, Grid r30 w700 Sort, Process|Tooltip|Visible|Handle
oIcons := TrayIcon_GetInfo()

Loop, % oIcons.MaxIndex() {
	proc := oIcons[A_Index].Process
	ttip := oIcons[A_Index].tooltip
	tray := oIcons[A_Index].Tray
	hWnd := oIcons[A_Index].hWnd
	vis := (tray == "Shell_TrayWnd") ? "Yes" : "No"
	LV_Add(, proc, ttip, vis, hWnd)
}

LV_ModifyCol()
LV_ModifyCol(3, "AutoHdr") ; Auto-size the 3rd column, taking into account the header's text

Gui Show, Center, System Tray Icons (F5 to reload, Esc to exit)
Return

GuiEscape:
GuiClose:
	ExitApp


;
;--------------------------End of auto-execute section--------------------------
;

#if WinActive("ahk_id" g_listViewHwnd)
F5::Reload
#if