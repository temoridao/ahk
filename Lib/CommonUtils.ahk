/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\AVarValuesRollback.ahk
#include %A_LineFile%\..\StaticClassBase.ahk
#include %A_LineFile%\..\Funcs.ahk
#include %A_LineFile%\..\LogUtils.ahk
#include %A_LineFile%\..\ErrMsg.ahk

/**
 * Utility class containing various useful functions, constants, etc not belonging to
 * particular category
 */
class CommonUtils extends StaticClassBase {
;public:
	class Constants {
		static PinnedWindowMark := "† " ; "📍 "
	}

	class WinGeometry
	{
		__New(x, y, width, height) {
			this.x := x
			this.y := y
			this.width := width
			this.height := height
		}

		x := y := width := height := ""
	}

	resolveExecutablePath(executableName) {
		exeStr := strAlloc(MAX_PATH := 260, executableName)
		if (DllCall("Shlwapi.dll\PathFindOnPath", "Str", exeStr, "Ptr*", 0)) {
			return exeStr
		}

		;Not found in PATH
		return ""
	}

	/**
	 * Finds a nearest existing directory.
	 *
	 * Goes up in the @p path directory hierarchy until valid existing directory found
	 *
	 * @param   dirPath  The dir path
	 *
	 * @return  The nearest existing parent directory from the @p dirPath hierarchy or @p dirPath
	 *          itself if it is already exist
	 */
	findNearestExistingDirectory(dirPath) {
		while (dirPath) {
			if (InStr(FileExist(dirPath), "D")) {
				return dirPath
			} else {
				if (!InStr(dirPath, "\")) {
					dirPath := ""
					break
				}
				dirPath := RegExReplace(dirPath, "(.*)\\{1,}.*$", "$1")
			}
		}

		return dirPath
	}

	/**
	 * Restores explorer directories along with their geometry
	 *
	 * Restores explorer.exe's directories from @p pathAndWinGeometry on the screen, creating new
	 * instances or restoring already opened windows.
	 *
	 * The @p pathAndWinGeometry is an array of objects and has the following structure
	 * (@c geometry and @c selectedFiles keys are optional):
	 * @code
	   "pathAndWinGeometry": [{
	     "path": "C:\Users\cool_user\Desktop\"
	     "geometry": {
	      "height": 680,
	      "width": 1306,
	      "x": 257,
	      "y": 235
	     },
	     "selectedFiles": ["C:\Absolute\Path\To\Files\To\Be\Selected"],
	   }]
	 * @endcode
	 *
	 * The @p options can have the following values:
	 * - A
	 *  If directory specified by @c path key doesn't exist, try to open its parent directory. The
	 *  process continues until the first existing directory found up to root drive letter
	 *
	 * @param   pathAndWinGeometry  The path to directory and its window geometry to be restored.
	 *                              See detailed description for the structure of this object
	 * @param   options             The options affecting restoration behavior
	 *
	 * @return  An array, each element of which is a path that cannot be restored (or partially
	 *          restored if @c "A" option specified in @p options)
	 */
	reopenExplorerWindows(pathAndWinGeometry, options := "") {
		raii := new AVarValuesRollback("A_TitleMatchMode=3") ; Exact title match
		optTryOpenNearestDirectory := InStr(options, "A")

		nonExistentFoldersIndices := []
		for i, value in pathAndWinGeometry {
			if (CommonUtils.isSpecialFolder(value.path)) {
				Run % value.path
				continue
			}

			path := value.path
			if (!FileExist(path)) {
				nonExistentFoldersIndices.Push(i)

				if (optTryOpenNearestDirectory) {
					if (!(path := CommonUtils.findNearestExistingDirectory(path))) {
						continue
					}
				} else {
					continue
				}

			}

			WinExist(path) ? WinActivate() : Run("explorer.exe """ path """")
		}

		for i, value in pathAndWinGeometry {
			if (HasVal(nonExistentFoldersIndices, i)) {
				continue ; Do not try to wait for non-existent folders
			}

			WinWait % value.path,,2
			if (value.geometry) {
				if (value.geometry.x = -32000) { ;this means that window was minimized when closed, so restore it with some default geometry
					WinMove % value.path,, A_ScreenWidth/8, A_ScreenHeight/6, A_ScreenWidth/1.3, A_ScreenHeight/1.3
				} else {
					WinMove % value.path,, value.geometry.x, value.geometry.y, value.geometry.width, value.geometry.height
				}
			}

			if (value.selectedFiles.Length()) {
				CommonUtils.setExplorerSelection(WinGet("ID", value.path), value.selectedFiles)
			}
		}

		listOfFailedFolders := []
		for i, value in nonExistentFoldersIndices {
			listOfFailedFolders.Push(pathAndWinGeometry[value].path)
		}

		return listOfFailedFolders
	}
	reopenExplorerWindow(path, winGeom := "", selectedFile := "", options := "") {
		return CommonUtils.reopenExplorerWindows([{path : path, geometry: winGeom, selectedFiles: [selectedFile]}], options)
	}
	; Special folders like "This PC", "Control Panel", etc which represented as CLSID values f.e. ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
	isSpecialFolder(path) {
		return InStr(path, "::{")
	}

	ActiveControlClass() {
		return WinGetClass("ahk_id" ControlGet("HWND",, ControlGetFocus("A"), "A"))
	}

	isWindowFullScreen(winTitle) {
		If (!WinExist(winTitle)) {
			Return false
		}

		WinGetPos,,,winW, winH
		; 0x800000 is WS_BORDER.
		; 0x20000000 is WS_MINIMIZE.
		; no border and not minimized
		Return !((WinGet("Style") & 0x20800000) || winH < A_ScreenHeight || winW < A_ScreenWidth)
	}

	getWinGeometry(winTitle := "") {
		WinGetPos winX, winY, winW, winH, % winTitle
		return new this.WinGeometry(winX, winY, winW, winH)
	}

	windowInfo(winTitle := "") {
		return { title               : WinGetTitle(winTitle)
		       , procName            : WinGet("ProcessName", winTitle)
		       , pid                 : WinGet("PID", winTitle)
		       , class               : WinGetClass(winTitle)
		       , count               : WinGet("Count", winTitle)
		       , IsWindowVisible     : !DllCall("IsWindowVisible", "Ptr", WinGet("ID", winTitle))
		       , hWnd                : WinGet("ID", winTitle)
		       , isFullscreen        : CommonUtils.isWindowFullScreen(winTitle)
		       , DetectHiddenWindows : A_DetectHiddenWindows }
	}

	WinGetClientSize(ByRef w, ByRef h, winTitle := "") {
		hWnd := WinExist(winTitle)
		VarSetCapacity(rect, 16)
		DllCall("GetClientRect", "uint", hWnd, "uint", &rect)
		w := NumGet(rect, 8, "int")
		h := NumGet(rect, 12, "int")
	}

	; This function uses current A_TitleMatchMode
	IsDesktop(winTitle := "") {
		WinGetTitle, title, %winTitle%
		; WinGet procName, ProcessName, ahk_id %winId%
		; Return (procName = "explorer.exe") && !title ; explorer.exe without title is desktop
		Return title = "Program Manager" || !title
	}

	ActiavateDesktop() {
		raii := new AVarValuesRollback("A_TitleMatchMode=RegEx")
		WinActivate ahk_class Progman|WorkerW
	}

	isWindowHidden(winTitle := "") {
		raiiLastFoundWnd := avarguard("A_LastFoundWindow")
		raii := avarguard("A_DetectHiddenWindows=OFF")
		hiddenOffHwnd := WinExist(winTitle)
		raii := avarguard("A_DetectHiddenWindows=ON")
		hiddenOnHwnd := WinExist(winTitle)
		return !hiddenOffHwnd && hiddenOnHwnd
	}

	; Check if mouse cursor is over window matching \p winTitle and returns its hWnd or zero if no such window exist.
	; If \p winTitle is empty, just returns hWnd of the window the mouse cursor is over now
	; If return value is non-zero, the Last Found Window is also updated
	MouseIsOver(winTitle := "", updateLastFoundWindow := true) {
		MouseGetPos,,, hWnd
		lastFoundHwnd := WinExist()
		mouseOverHwnd := WinExist(winTitle " ahk_id " hWnd) ; ahk_id correctly handles one or more leading spaces (if winTitle is empty for example)
		if (!updateLastFoundWindow)
			WinExist("ahk_id" lastFoundHwnd)
		return mouseOverHwnd
	}

	MouseIsOverTaskbar() {
		raii := new AVarValuesRollback("A_TitleMatchMode=RegEx")
		return this.MouseIsOver("ahk_class Shell_TrayWnd|Shell_SecondaryTrayWnd")
	}

	MouseIsOverControl(controlClass) {
		MouseGetPos,,,, hoverCtrlClass
		if (A_TitleMatchMode = "RegEx") {
			return hoverCtrlClass ~= controlClass
		} else if (A_TitleMatchMode = 1) {
			return InStr(hoverCtrlClass, controlClass) = 1
		} else if (A_TitleMatchMode = 2) {
			return InStr(hoverCtrlClass, controlClass)
		} else if (A_TitleMatchMode = 3) {
			return hoverCtrlClass = controlClass
		}
	}

	MouseIsOverDesktop() {
		CommonUtils.MouseIsOver()
		return CommonUtils.IsDesktop()
	}

	displayText(text) {
		ListVars
		WinWaitActive ahk_class AutoHotkey
		ControlSetText Edit1, %text%
	}

	restartExplorerExe() {
		Process, Close, explorer.exe
		Sleep 300
		Run explorer.exe
		WinWaitActive, ahk_class CabinetWClass,,5 ;wait at most 5 seconds until window apperas
		WinClose ;and close the last found window
	}

	killProcess(procName, killWithElevation := true) {
		if (killWithElevation) {
			Run *RunAs %A_ComSpec% /c taskkill /f /fi "IMAGENAME eq %procName%",,Hide
		} else {
			Run %A_ComSpec% /c taskkill /f /fi "IMAGENAME eq %procName%",,Hide
		}
	}

	triggerMenu(menuId, winTitle := "") {
		PostMessage WM_COMMAND := 0x111, %menuId%,,, %winTitle%
	}

	GetSelectedTextThroughClipboard(clipboardWaitSec := 1, restoreClipboard := true) {
		savedClipboard := ""
		if (restoreClipboard) {
			savedClipboard := ClipboardAll
		}

		Clipboard := ""
		Send ^c
		ClipWait %clipboardWaitSec%, 0
		clipText := Clipboard

		if (restoreClipboard) {
			Clipboard := savedClipboard
		}

		Return clipText
	}

	; @p options
	; 	x - remove text after copying
	getTextStringThroughClipboard(length := 0, restoreCaretPosition := true, options := "x") {
		optRemoveText := InStr(options, "x")

		charToMoveCaretBack := ""
		if (length < 0) {
			length := Abs(length)
			Send +{Left %length%}
			charToMoveCaretBack := "{Right}"
		} else if (length > 0) {
			Send +{Right %length%}
			charToMoveCaretBack := "{Left}"
		}
		result := CommonUtils.GetSelectedTextThroughClipboard(0.1)
		if (optRemoveText && result) {
			Send {Bs}
		} else if (restoreCaretPosition) {
			Send % charToMoveCaretBack
		}
		return result
	}

	/**
	 * Sends text through clipboard instead of direct `Send` command
	 *
	 * This has an advantage over direct `Send` in that this action is atomic from text editors' point of view and can be
	 * undo/redo by a single ^z or ^y or similar.
	 *
	 * NOTE: original clipboard content is restored after operation
	 *
	 * @param   content  The content to send
	 */
	sendThroughClipboard(content) {
		if (!content) {
			return
		}
		clipSaved := ClipboardAll
		Clipboard := content
		Send ^v
		Sleep 50
		Clipboard := clipSaved
	}

	getFirstExistingPath(pathList, throwIfNotFound := true) {
		for i, v in pathList
			if (FileExist(v))
				return v
		if (throwIfNotFound)
			throwException("Cannot find any existing file in " ObjToString(pathList))
	}

	;Enables close button again
	redrawSysMenu(hWnd := "") {
		if (!hWnd) {
			hWnd := WinExist()
		}

		DllCall("GetSystemMenu", "Int",hWnd, "Int",true)
		DllCall("DrawMenuBar", "Int",hWnd)

		winTitle := WinGetTitle()
		if (InStr(winTitle, this.Constants.PinnedWindowMark)) {
			WinSetTitle % RegExReplace(winTitle, this.Constants.PinnedWindowMark,,1)
		}
	}
	disableCloseButton(hWnd := "") {
		if (!hWnd) {
			hWnd := WinExist()
		}

		hSysMenu := DllCall("GetSystemMenu", "Int", hWnd, "Int", false)
		nCnt := DllCall("GetMenuItemCount", "Int", hSysMenu)
		DllCall("RemoveMenu", "Int", hSysMenu, "UInt", nCnt-1, "Uint", "0x400")
		DllCall("RemoveMenu", "Int", hSysMenu, "UInt", nCnt-2, "Uint", "0x400")
		DllCall("DrawMenuBar", "Int", hWnd)

		winTitle := "ahk_id" hWnd
		title := WinGetTitle(winTitle)
		if (InStr(title, this.Constants.PinnedWindowMark)) {
			return
		}

		WinSetTitle, %winTitle%,, % this.Constants.PinnedWindowMark . title
	}

	allowWindowClose(hWnd := "") {
		if (!hWnd) {
			hWnd := WinExist()
		}

		return !InStr(WinGetTitle(), this.Constants.PinnedWindowMark)
	}

	/**
	 * Send lightweight request (SC_CLOSE) to close a window
	 *
	 * Similar in effect to pressing Alt+F4 or clicking the window's close button in its title bar.
	 * Useful for applications which do not handle WM_CLOSE (sent by built-in WinClose command)
	 * gracefully and unable to save their state properly or even crashed.
	 *
	 * @param   winTitle  The window title
	 * @param   method    Possible values: "PostMessage", "SendMessage"
	 *
	 * @return  Empty value if @p method is "PostMessage" (the default) and a reply value if @p method
	 *          is "SendMessage"
	 */
	SendCloseMessage(winTitle := "", method := "PostMessage") {
		return method = "PostMessage" ? PostMessage(WM_SYSCOMMAND:=0x112, SC_CLOSE:=0xF060,,, winTitle)
		                              : SendMessage(WM_SYSCOMMAND:=0x112, SC_CLOSE:=0xF060,,, winTitle)
	}

	; Returns unique filesystem path to save new file to. The save directory is extracted from active explorer.exe's window title.
	; Empty string returned if \p promptForName is \c true and prompt-dialog canceled by user
	; Exception thrown if active window is not explorer.exe's process
	getSaveFilePath(promptForName := true, defaultFileName := "", promptText := "Enter file name:") {
		if (WinGet("ProcessName", "A") != "explorer.exe") {
			Throw "'" A_ThisFunc "()' function works only for active explorer.exe windows"
		}

		if (!promptForName && !defaultFileName) {
			defaultFileName := "NewFile-" . FormatTime("", "dd-MMM-yyyy_HHmmss") . ".txt" ; example timestamp: '16-Jul-2019_144616'
		}

		dir := CommonUtils.IsDesktop("A") ? A_Desktop : CommonUtils.WinGetTitleEx("A")

		filename := defaultFileName
		if (promptForName) {
			filename := InputBox(promptText,,, 400, 100,,,,, defaultFileName)
			if (ErrorLevel)	{
				Return ""
			}
		}

		return CommonUtils.getUniqueFilesystemPath(dir "\" filename)
	}


	getAhkScriptFilePath(hWnd) {
		if (!WinExist("ahk_id" hWnd)) {
			return ""
		}

		if (WinGet("ProcessName") != "AutoHotkey.exe") {
			return ""
		}

		; Command line parsing approach: may return relative path if the script was launched by relative path
		;commandLine := CommonUtils.getProcessCommandLine(WinGet("PID"))
		;; OutputDebug % commandLine
		;RegExMatch(commandLine, "iO).+""?([a-z]:.+?\.ahk)""?", matchObj)
		;; OutputDebug % matchObj.Value(1)
		;scriptPath := matchObj.Count() ? matchObj.Value(1) : scriptPath

		; Hidden AutoHotkey's window title parsing approach (more reliable): the title always have full absolute path to the script.ahk, even if AutoHotkey.exe was launched with relative path to the script
		raii := new AVarValuesRollback("A_DetectHiddenWindows=On|A_TitleMatchMode=3")
		title := WinGetTitle("ahk_pid" WinGet("PID") " ahk_class AutoHotkey")
		; OutputDebug % "raw:" title
		scriptPath := SubStr(title, 1, InStr(title, " - AutoHotkey v"))
		; OutputDebug % "parsed: " scriptPath
		return Trim(scriptPath)
	}

	/**
	 * Shows the splash text with optional picture
	 *
	 * @param   pPicturePath    The picture path. Can also be a path to .exe, .dll
	 * @param   pPictureX       The picture x position
	 * @param   pPictureY       The picture y position
	 * @param   pTextToDisplay  The text to display
	 * @param   pTextX          The text x position
	 * @param   pTextY          The text y position
	 * @param   pFontSize       The font size
	 * @param   pDuration       The duration of visibility. Pass 0 to not hide the splash until the
	 *                          next call to this function with @p pDuration > 0
	 * @param   pTransparent    The color to be interpreted as transparent. See `WinSet, TransColor`
	 *
	 */
	ShowSplashPictureWithText(pPicturePath := "", pPictureX := "Center", pPictureY := "Center"
		                    , pTextToDisplay := "", pTextX := "Center", pTextY := "Center", pFontSize := 20
		                    , pDuration := 1000, pTransparent := true, textColor := "66D9EF") {
		Static cPictureBackgroundColor := "E5F3FF"
		Static cTextBackgroundColor := "272822"

		Static sHwndVolumeText := ""

		;---
		Gui GuiText:Default
		Gui +LastFoundExist
		fontOptions := "cWhite s" pFontSize "q5 c" textColor
		if (!WinExist()) {
			Gui Margin, 0, 0
			Gui Font, % fontOptions
			Gui Color, % cTextBackgroundColor
			Gui Add, Text, +HWNDsHwndVolumeText Center Wrap, %pTextToDisplay%
			Gui +LastFound -Caption +AlwaysOnTop +ToolWindow +Border
		}
		Gui Font, % fontOptions ;update font options
		GuiControl Font, % sHwndVolumeText ;set updated options for control's handle
		this.SetTextAndResize(sHwndVolumeText, pTextToDisplay, fontOptions)
		Gui Show, Center x%pTextX% y%pTextY% AutoSize NoActivate

		;---
		if (pPicturePath) {
			;Static cPicMinimumSize := 48
			Static sHwndPic
			Gui GuiPicture:New, +LastFound -Caption +AlwaysOnTop +ToolWindow
			Gui Margin, 0, 0
			Gui Add, Picture, +HWNDsHwndPic, %pPicturePath%

			; GuiControlGet originalDimension, Pos, %sHwndPic%
			; GuiControl Move, %sHwndPic%, % "w" Max(cPicMinimumSize, originalDimensionW) " h" originalDimensionH  ;resize control to at least minimum width. TODO: need to preserve aspect ration by applying some scale factor
			; OutputDebug % "Loaded picture (" originalDimensionW "x" originalDimensionH "): " pPicturePath

			Gui Color, %cPictureBackgroundColor%
			if (pTransparent) {
				Winset, TransColor, %cPictureBackgroundColor%
			}
			Gui Show, x%pPictureX% y%pPictureY% NoActivate ; TODO: place a picture under text. Do not use absolute positioning here by default
		}

		timerInterval := pDuration
		if (timerInterval = 0) {
			return
		} else if (timerInterval < 0) {
			timerInterval := Abs(pDuration)
		}

		SetTimer Sub_HideGui, -%timerInterval%
		Return

		Sub_HideGui:
		Gui GuiPicture:Show, Hide
		Gui GuiText:Show, Hide
		Return
	}

	;Due to absence of built-in methods to automatically resize control based on its text, we need
	;calculate its size. See https://stackoverflow.com/a/49354127 for details
	SetTextAndResize(controlHwnd, newText, fontOptions := "", fontName := "") {
		Gui TemporaryGui:Font, %fontOptions%, %fontName%
		Gui TemporaryGui:Add, Text,, %newText%
		GuiControlGet T, TemporaryGui:Pos, Static1
		Gui TemporaryGui:Destroy

		GuiControl,, %controlHwnd%, %newText%
		GuiControl Move, %controlHwnd%, % "h" TH " w" TW
	}

	ShowToolTip(text, timeout := 3000, addScriptName := true) {
		ToolTip % (addScriptName ? "-----" A_ScriptName "-----`n" : "") text
		if (timeout) {
			SetTimer("ToolTip", -Abs(timeout))
		}
	}

	ShowText(text:="", timeout := 3000, pOpts := "", font := "") {
		if (!text) {
			Progress OFF
			return
		}

		options := "B zh0 Fs16 W500 " pOpts
		Progress, %options%, %text%,,,%font%

		if (timeout) {
			SetTimer(Func("Progress").Bind("OFF"), -Abs(timeout))
		}
	}

	;Assigns icon to script if finds one in %baseDir% with name identical to calling script
	;plus png|ico|jpg extension. For example %baseDir%\Starter.ahk.ico for script named Starter.ahk
	;Pass path to icon in `overrideTrayIcon` parameter to apply it unconditionally or "*" to restore
	;original icon. Returns icon path which actually applied or empty string if error occurs
	SetupTrayIcon(freezeIcon := false, overrideTrayIcon := "", baseDir := "") {
		if (overrideTrayIcon && FileExist(overrideTrayIcon)) {
			Menu, Tray, Icon , % overrideTrayIcon,, % freezeIcon
			Return overrideTrayIcon
		}

		resultIcon := ""
		Loop Files, % baseDir . (baseDir ? "\" : "") A_ScriptName ".*"
		{
			if (RegExMatch(A_LoopFileExt, "i)png|ico|jpg")) {
				resultIcon := A_LoopFilePath
				break
			}
		}

		if (resultIcon && FileExist(resultIcon)) {
			Menu, Tray, Icon , % resultIcon,, % freezeIcon
		}

		Return resultIcon
	}

	showOnscreenKeyboard() {
		hWnd := WinGet("ID", "A")
		WinActivate("ahk_class Progman")
		Run tabtip
		Sleep 300
		WinActivate("ahk_id" hWnd)
	}

	sendInputToWindow(keys, winTitle := "", useRegularSendIfAlreadyActiveWindow := false) {
		if (useRegularSendIfAlreadyActiveWindow && (WinGet("ID", winTitle) = WinGet("ID", "A"))) {
			return Send(keys)
		}
		ControlSend, ahk_parent, %keys%, %winTitle% ;ahk_parent used for sending input directly to the target window
	}

	toggleWindowAlwaysOnTop(winTitle := "", alwaysOnTopTitlePrefix := "★ ") {
		WinGet, estyle, ExStyle, %winTitle%
		WinGetTitle, title, %winTitle%
		if (estyle & 0x8) { ; 0x8 is WS_EX_TOPMOST.
			 if (InStr(title, alwaysOnTopTitlePrefix)) {
				title := RegExReplace(title, alwaysOnTopTitlePrefix,,1)
			}
		} else {
			if (!InStr(title, alwaysOnTopTitlePrefix)) {
				title := alwaysOnTopTitlePrefix . title
			}
		}

		WinSetTitle, %winTitle%, , %title%
		Winset, AlwaysOnTop, , %winTitle%
	}

	;\p extractionOpts is combination of letters (in any order, case-insensitive):
	;  P - Use precise method of word extraction with regular expression.
	;      By default, more naive method used, observing word boundaries with ^+{Left} and ^+{Right} shortcut supported in most text editors
	;  D - include decimal digits as part of word in addition to letters and underscore. Has no effect unless "P" option is specified
	;  x - remove word under cursor
	getWordUnderCursor(extractionOpts := "") {
		savedClipboard := Clipboard
		Clipboard := ""
		keyword := ""

		raii := new AVarValuesRollback("A_SendMode=Event")
		optRemoveWord := InStr(extractionOpts, "x")
		optUsePreciseMethod := InStr(extractionOpts, "P")

		if (optUsePreciseMethod) {
			optIncludeDigits := InStr(extractionOpts, "D")
			cRegexWordChar := "[\p{Ll}\p{Lu}_" (optIncludeDigits ? "0-9" : "") "]" ; any unicode letter and underscore
			cRegexNonWordChar := "[^" SubStr(cRegexWordChar, 2) ; just ^-negated version of above regex

			str := ""
			; Get string to the left of cursor and restore cursor position
			Send +{Home}^c{Right}
			ClipWait 0.1
			selectionLengthBeforeCursor := StrLen(Clipboard)
			str .= Clipboard

			; Get string to the right of cursor and restore cursor position
			Send +{End}^c{Left}
			ClipWait 0.1
			selectionLengthAfterCursor := StrLen(Clipboard)
			str .= Clipboard

			;NOTE: 'Nw' below means 'non-word-character'
			rightNwPos := RegExMatch(str, cRegexNonWordChar,, selectionLengthBeforeCursor)

			leftSubstring := SubStr(str, 1, selectionLengthBeforeCursor)
			firstNwPosToTheLeftOfCursor := 0
			pos := 1
			while true { ; Find pos of last non-word character
				pos := RegExMatch(leftSubstring, cRegexNonWordChar,, pos)
				if (pos = 0) {
					break
				} else {
					firstNwPosToTheLeftOfCursor := ++pos
				}
			}
			if (firstNwPosToTheLeftOfCursor > 1) {
				--firstNwPosToTheLeftOfCursor
			}

			cursorOffsetFromWordStart := selectionLengthBeforeCursor - firstNwPosToTheLeftOfCursor
			wordLength := 0
			if (firstNwPosToTheLeftOfCursor < rightNwPos || rightNwPos = 0) { ; The cursor is in the middle of the word, so extract the word
				wordLength := rightNwPos - firstNwPosToTheLeftOfCursor - 1
				keyword := SubStr(str, firstNwPosToTheLeftOfCursor + 1, wordLength <= 0 ? 1000 : wordLength) ; 1000 here is a big number and means "all characters till end of line"
			} else if (SubStr(str, firstNwPosToTheLeftOfCursor + 1, 1) ~= cRegexWordChar) { ; If the next character is word-character, then cursor probably stay at the beginning of the word, so check characters to the right
					pos := RegExMatch(str, cRegexNonWordChar,, firstNwPosToTheLeftOfCursor + 1)
					if (pos) {
						wordLength := pos - firstNwPosToTheLeftOfCursor - 1
						keyword := SubStr(str, firstNwPosToTheLeftOfCursor + 1, wordLength)
					}
			} else {
				; OutputDebug % "Text cursor is not inside the word nor at the beginning of word"
			}
			if (optRemoveWord && wordLength) {
				Send {Left %cursorOffsetFromWordStart%}+{Right %wordLength%}{BackSpace}
			}

			; OutputDebug % "L: " selectionLengthBeforeCursor " R: " selectionLengthAfterCursor " LNW: " firstNwPosToTheLeftOfCursor " RNW: " rightNwPos " Parsed: `'" keyword "`'"
		} else {
			;Go to beginning of the word under cursor
			Send ^+{Left}^c
			; ClipWait 0.2
			selectionLengthBeforeCursor := StrLen(Clipboard)

			;Select whole word to the right
			Send {Left}^+{Right}^c
			ClipWait 0.2

			wordLength := StrLen(Clipboard)
			(optRemoveWord && wordLength) ? Send("{BackSpace}")
			                           : Send("{Left}{Right %selectionLengthBeforeCursor%}") ;Restore previous cursor position
			keyword := RegExReplace(Clipboard, "\s") ;delete all whitespaces
		}

		Clipboard := savedClipboard
		return keyword
	}

	KeyWait(keys := "{All}", hookOptions := "") {
		ih := InputHook(hookOptions)
		ih.KeyOpt(keys, "ES")  ; End and Suppress
		ih.Start()
		ErrorLevel := ih.Wait()  ; Store EndReason in ErrorLevel
		return ih.EndKey  ; Return the key name
	}

	IsAltTabMenuOnScreen() {
		return WinExist("ahk_class MultitaskingViewFrame")
	}

	getProcessCommandLine(pid) {
		wmi := ComObjGet("winmgmts:")
		; raii := new AVarValuesRollback("A_DetectHiddenWindows=On")

		; Run query to retrieve matching process(es).
		; Win32_Process: http://msdn.microsoft.com/en-us/library/aa394372.aspx
		queryEnum := wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId=" pid)._NewEnum()

		; Get first matching process.
		return queryEnum[proc] ? proc.CommandLine : ""
	}

	getProcessCurrentDirectory(pid) {
		PROCESS_QUERY_INFORMATION := 0x400, PROCESS_VM_READ := 0x10, STATUS_SUCCESS := 0

		hProc := DllCall("OpenProcess", "UInt", PROCESS_QUERY_INFORMATION|PROCESS_VM_READ, "Int", 0, "UInt", pid, "UInt")
		isWow64Proc := false
		(A_Is64bitOS && DllCall("IsWow64Process", "Ptr", hProc, "UIntP", isWow64Proc))

		PtrSize := 8, PtrType := "Int64", pPtr := "Int64P"
		if (!A_Is64bitOS || isWow64Proc)
			PtrSize := 4, PtrType := "UInt", pPtr := "UIntP"
		offsetCURDIR := 4*4 + PtrSize*5

		failed := false
		hModule := DllCall("GetModuleHandle", "str", "Ntdll", "Ptr")
		info := szPBI := offsetPEB := 0
		if (A_PtrSize < PtrSize) {            ; <<—— script 32, target process 64
			if (!QueryInformationProcess := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "NtWow64QueryInformationProcess64", "Ptr"))
				failed := "NtWow64QueryInformationProcess64"
			if (!ReadProcessMemory := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "NtWow64ReadVirtualMemory64", "Ptr"))
				failed := "NtWow64ReadVirtualMemory64"
			info := 0, szPBI := 48, offsetPEB := 8
		} else {
			if (!QueryInformationProcess := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "NtQueryInformationProcess", "Ptr"))
				failed := "NtQueryInformationProcess"
			ReadProcessMemory := "ReadProcessMemory"
			if (A_PtrSize > PtrSize)            ; <<—— script 64, target process 32
				info := 26, szPBI := 8, offsetPEB := 0
			else                                ; <<—— script and target process have the same bitness
				info := 0, szPBI := PtrSize * 6, offsetPEB := PtrSize
		}
		if (failed) {
			DllCall("CloseHandle", "Ptr", hProc)
			MsgBox, Format("Failed to get pointer to {}: ", failed, ErrMsg())
			Return
		}

		VarSetCapacity(PBI, 48, 0)
		bytes := ""
		if (DllCall(QueryInformationProcess, "Ptr", hProc, "UInt", info, "Ptr", &PBI, "UInt", szPBI, "UIntP", bytes) != STATUS_SUCCESS)  {
			MsgBox % Format("Failed call to QueryInformationProcess ({:#x}): {}", QueryInformationProcess, ErrMsg())
			DllCall("CloseHandle", "Ptr", hProc)
			Return
		}

		pPEB := NumGet(&PBI + offsetPEB, PtrType)
		pRUPP := szBuff := pCURDIR := ""
		DllCall(ReadProcessMemory, "Ptr", hProc, PtrType, pPEB + PtrSize * 4, pPtr, pRUPP, PtrType, PtrSize, "UIntP", bytes)
		DllCall(ReadProcessMemory, "Ptr", hProc, PtrType, pRUPP + offsetCURDIR, "UShortP", szBuff, PtrType, 2, "UIntP", bytes)
		DllCall(ReadProcessMemory, "Ptr", hProc, PtrType, pRUPP + offsetCURDIR + PtrSize, pPtr, pCURDIR, PtrType, PtrSize, "UIntP", bytes)

		VarSetCapacity(buff, szBuff, 0)
		DllCall(ReadProcessMemory, "Ptr", hProc, PtrType, pCURDIR, "Ptr", &buff, PtrType, szBuff, "UIntP", bytes)
		DllCall("CloseHandle", "Ptr", hProc)
		Return currentDirPath := StrGet(&buff, "UTF-16")
	}

	getUniqueFilesystemPath(filePath) {
		lastSlashPos := InStr(filePath, "`\", false, 0)
		dotPos := InStr(filepath, ".", false, lastSlashPos ? (lastSlashPos + 1) : 0)
		hasExtension := dotPos != 0

		baseName     := hasExtension ? SubStr(filepath, 1, dotPos-1) : filepath
		dotExtension := hasExtension ? SubStr(filepath, dotPos) : "" ; file extension with dot, f.e. ".bat"

		postfix := ""
		Loop {
			path := hasExtension ? (baseName . postfix . dotExtension) : (baseName . postfix)
			if (!FileExist(path)) {
				filePath := path
				break
			}

			postfix := " (" A_Index ")"
		}

		return filePath
	}

	getMonitorNumberUnderMouseCursor() {
		oldCoordMode := A_CoordModeMouse
		CoordMode Mouse, Screen
		MouseGetPos mx, my
		CoordMode Mouse, % oldCoordMode

		result := 0
		Loop % SysGet("MonitorCount") {
			SysGet m, Monitor, % A_Index
			if (mx >= mLeft && mx <= mRight && my >= mTop && my <= mBottom) {
				result := A_Index
				break
			}
		}

		return result
	}

	;Maximized state geometry can be overwritten by passing in \p overrideProcGeom offsets on per
	;process basis to get even more working space on display in maximized mode.
	;Object's format is {"qtcreator.exe" : {x: 0, y: -30, w: 0, h: 30}}, where x,y,w,h keys are
	;relative offsets/deltas to left/top edges and width/height of the monitor's dimensions
	toggleMaximizeState(winTitle:="", removeWinBorders := false, overrideProcGeom := "") {
		if !WinExist(winTitle) || CommonUtils.IsDesktop(winTitle) {
			return
		}

		;***Simple maximize/minimize toggle
		if (!removeWinBorders) {
			return (isMaximized := WinGet("MinMax") = 1) ? WinRestore() : WinMaximize()
		}

		;***Manually resize window to fill screen AND remove borders
		if (WinGet("Style") & 0xC40000) {
			WinRestore
			WinSet Style, -0xC40000

			SysGet mon, Monitor, % CommonUtils.getMonitorNumberUnderMouseCursor()
			monWidth := monRight - monLeft
			monHeight := monBottom - monTop

			if (g := overrideProcGeom[WinGet("ProcessName")]) {
				WinMove,,, monLeft + g.x, monTop + g.y - 1, monWidth + g.w, monHeight + g.h ;subtract 1px from y-position to allow taskbar access if it is located at the bottom edge and has auto-hide feature enabled.
			} else {
				WinMove,,,monLeft,monTop-1,monWidth, monHeight ;and subtract 1px from y-position here
			}
		} else {
			WinSet Style, +0xC40000
			WinMaximize
		}
	}

	; Move window to the center of monitor with mouse cursor
	centerWindow(winTitle:="") {
		SysGet mon, Monitor, % CommonUtils.getMonitorNumberUnderMouseCursor()
		monWidth := monRight - monLeft
		monHeight := monBottom - monTop

		WinGetPos,,, winWidth, winHeight, %winTitle%
		WinMove %winTitle%,, monLeft + monWidth/2 - winWidth/2, monTop + monHeight/2 - winHeight/2
	}

	;Fits window size into monitor's (which contains mouse cursor) dimensions
	resetWindowSize(winTitle:="") {
		SysGet mon, Monitor, % CommonUtils.getMonitorNumberUnderMouseCursor()
		monWidth := monRight - monLeft
		monHeight := monBottom - monTop
		WinMove %winTitle%,,,, % monWidth * 0.9, % monHeight * 0.8
	}

	resetWinGeometry(winTitle:="") {
		CommonUtils.resetWindowSize(winTitle)
		CommonUtils.centerWindow(winTitle)
	}

	; If winTitle parameter's class matches "CabinetWClass", returns full path of the current folder
	; even if it is not fitting into window title (this can happen for directories with long names and/or high level of nesting)
	; For all other windows returns the standard result of WinGetTitle(winTitle)
	WinGetTitleEx(winTitle := "") {
		if (WinGetClass(winTitle) != "CabinetWClass") {
			return WinGetTitle(winTitle)
		}

		hWnd := WinExist(winTitle)
		for window in ComObjCreate("Shell.Application").Windows {
			if (window.hWnd = hWnd) {
				return window.Document.Folder.Self.Path
			}
		}
	}

	; Returns array with paths to selected files (if any) in the explorer.exe's window which
	; satisfy \p winTitle criteria (leave it empty to use Last Found Window)
	getSelectionFromExplorer(winTitle := "") {
		hWnd := WinExist(winTitle)

		procName := WinGet("ProcessName")
		if (procName != "explorer.exe") {
			return []
		}

		result := []

		winClass := WinGetClass()
		if (winClass ~= "Progman|WorkerW") {
			ControlGet, files, List, Selected Col1, SysListView321, ahk_class %winClass%
			Loop, Parse, files, `n, `r
			{
				result.Push(A_Desktop "\" A_LoopField)
			}
		} else if (winClass ~= "(Cabinet|Explore)WClass") {
			for window in ComObjCreate("Shell.Application").Windows {
				if (window.hWnd == hWnd) {
					for item in window.Document.SelectedItems {
						result.Push(item.path)
					}
					break
				}
			}
		}

		return result
	}

	getFilesFromExplorer(winTitle := "") {
		hWnd := WinExist(winTitle)
		procName := WinGet("ProcessName")
		if (procName != "explorer.exe") {
			return []
		}

		result := []
		for window in ComObjCreate("Shell.Application").Windows {
			if (window.hWnd != hWnd) {
				continue
			}
			for item in window.Document.Folder.Items {
				result.Push(item.path)
			}
			break
		}

		return result
	}

	comObjectInfo(comObj) {
		VarType := ComObjType(comObj)
		IName   := ComObjType(comObj, "Name")
		IID     := ComObjType(comObj, "IID")
		CName   := ComObjType(comObj, "Class")
		CLSID   := ComObjType(comObj, "CLSID")

		return "Variant type:`t" VarType
		      . "`nInterface name:`t" IName "`nInterface ID:`t" IID
			    . "`nClass name:`t" CName "`nClass ID (CLSID):`t" CLSID
	}

	; Returns {hWnd: [full, paths, to, selected, files]}
	getSelectionFromAllExplorerWindows() {
		result := {}
		; `window` is an instance of IWebBrowser interface of Shell.Explorer.2 class object (https://stackoverflow.com/questions/18638837/find-documentation-for-activex-object-shell-explorer-2, https://docs.microsoft.com/en-us/windows/win32/shell/shell-windows)
		; `window.Document` is an instance of IShellFolderViewDual3 interface: https://docs.microsoft.com/en-us/windows/win32/shell/shellfolderview
		for window in ComObjCreate("Shell.Application").Windows {
			result[window.hWnd] := []
			for item in window.Document.SelectedItems {
				result[window.hWnd].Push(item.path)
			}
		}
		return result
	}
	setExplorerSelection(hWnd, filesToSelect) {
		for window in ComObjCreate("Shell.Application").Windows {
			if (window.hWnd != hWnd) {
				continue
			}

			scrolled := false
			for item in window.Document.Folder.Items { ; 'Folder' property is ShellFolderView interface: https://docs.microsoft.com/en-us/windows/win32/shell/shellfolderview
				if (!HasVal(filesToSelect, item.path)) {
					continue
				}

				if (!scrolled) {
					window.Document.SelectItem(item, 8) ; Scroll view to make the first file in selection visible
					scrolled := true
				}

				window.Document.SelectItem(item, 1)
			}
		}
	}

	; Applies new desktop wallpaper \p wallpaperPath and returns original wallpaper path. Leave blank to set black screen wallpaper
	; To set new and restore original wallpaper on script exit, add the following to your script auto-execute section:
	;     OnExit(ObjBindMethod(CommonUtils, "setDesktopWallpaper", CommonUtils.setDesktopWallpaper("c:\full\path\to\wallpaper.jpg")))
	setDesktopWallpaper(wallpaperPath := "") {
		originalWallpaper := this.desktopWallpaper()

		SPIF_UPDATEINIFILE   := 0x1 ; writes change to user profile (ensures change is persistent until next call to SystemParametersInfo())
		SPIF_SENDCHANGE      := 0x2 ; broadcasts WM_SETTINGSCHANGE to all top level windows
		SPI_SETDESKWALLPAPER := 0x14
		DllCall("SystemParametersInfo"
			, "UInt", SPI_SETDESKWALLPAPER
			, "UInt", 0
			, "Str", wallpaperPath
			, "UInt", SPIF_SENDCHANGE | SPIF_UPDATEINIFILE)
		return originalWallpaper
	}
	; Returns path to current desktop wallpaper
	desktopWallpaper() {
		return RegRead("HKCU\Control Panel\Desktop", "Wallpaper")
	}

	; Returns the filename (without path) with most recent time footprint as determined by \p dateType
	getMostRecentFilePath(filePattern, dateType := "") {
		files := CommonUtils.getDateSortedFiles(filePattern, dateType)
		return files[files.Length()]
	}

	/**
	 * Get path for all files sorted by date (ascending)
	 *
	 * @param   filePattern  The file pattern as in `Loop, Files`
	 * @param   dateType     The string with A_-variable name for desired date type,
	 *                       f.e. "A_LoopFileTimeModified" (the default) or "A_LoopFileTimeCreated", etc.
	 *
	 * @return  An array of full paths to files matching @p filePattern sorted by date
	 *          type @p dateType in ascending order (from oldest to the most recent file)
	 */
	getDateSortedFiles(filePattern, dateType := "") {
		if (!filePattern) {
			filePattern := A_ScriptDir "\*.*"
		}
		if (!dateType)
			dateType := "A_LoopFileTimeModified"

		fileList := ""
		Loop, Files, %filePattern%, FD
		{
			fileList .= %dateType% "`t" A_LoopFileLongPath "`n"
		}

		Sort fileList ;sort by date: from oldest to recent

		filesArray := []
		Loop, Parse, fileList, `n
		{
			filesArray.Push(StrSplit(A_LoopField, A_Tab)[2]) ; Split into two parts at the tab char.
		}
		filesArray.RemoveAt(filesArray.Length())
		return filesArray
	}

	createFileBackup(sourceFiles, maxBackupCount := 2, backupExtension := ".backup", opts := "") {
		optUseShell := InStr(opts, "S")
		sourceFiles := IsObject(sourceFiles) ? sourceFiles : [sourceFiles]
		shellFlags := sourceFiles.Length() > 1 ? (WinShell.FOF_NOCONFIRMATION | WinShell.FOF_NOCONFIRMMKDIR) : 0

		currentTimeStamp := FormatTime("", "dd-MM-yyyy_HH_mm_ss")
		failedFiles := []
		for i, filePath in sourceFiles {
			newBackupFilePath := filePath . backupExtension . currentTimeStamp
			existingBackups := CommonUtils.getDateSortedFiles(filePath . backupExtension . "*", "A_LoopFileTimeCreated")
			if (existingBackups.Length() >= maxBackupCount) {
				FileRecycle % existingBackups[1] ;Delete oldest backup
			}
			fAttr := FileExist(filePath)
			if (!fAttr) {
				continue
			}

			if (optUseShell) {
				if (!WinShell.Copy(filePath, newBackupFilePath, shellFlags)) {
					failedFiles.Push(newBackupFilePath)
				}
			} else {
				InStr(fAttr, "D") ? FileCopyDir(filePath, newBackupFilePath, true)
				                  : FileCopy(filePath, newBackupFilePath, true)
				if (ErrorLevel) {
					failedFiles.Push(newBackupFilePath)
				}
			}
		}
		if (failedFiles.Length()) {
			logWarn("failedFiles:", failedFiles)
		}
		return !failedFiles.Length()
	}

	askPermissionMsgBox(description, question := "Continue?", title := "") {
		MsgBox,4, % (title ? title : A_ScriptName), % description . (question ? ("`n`n" question) : "")
		IfMsgBox No
			return false

		return true
	}

	; Allows to determine key press status even if key was pressed before script launched (AHK's GetKeyState() does not work in this case)
	isKeyboardKeyPressedDllCall(ahkKeyName) {
		return Dllcall("GetAsyncKeyState", "int", GetKeyVK(ahkKeyName), "short") >> 15
	}

	; This function usually should be called at the top part of your script, which you want to be [re]started with elevated rights
	; Calling this function is equivalent to "Run as Administrator" standard windows context menu element
	elevateThisScript(guardAgainstRecursion := true) {
		if !(A_IsAdmin || (guardAgainstRecursion && InStr(DllCall("GetCommandLine", "str"), "/restart"))) {
			cmdline := ""
			for i, arg in A_Args {
				cmdline .= arg " "
			}
			try {
				if (A_IsCompiled) {
					Run *RunAs "%A_ScriptFullPath%" /CP65001 /restart %cmdline%
				} else {
					Run *RunAs "%A_AhkPath%" /CP65001 /restart "%A_ScriptFullPath%" %cmdline%
				}
			}
			ExitApp
		}
	}

	/**
	 * Reload the script (similar in effect to built-in @c Reload command) while preserving command
	 * line parameters
	 *
	 * @param   scriptWinTitle  The target script's window title. Omit this parameter to reload
	 *                          current script
	 * @param   titleMatchMode  This title match mode will be applied with SetTitleMatchMode before
	 *                          searching for a script with title @p scriptWinTitle
	 *
	 * @return  Process id of the new script instance or zero if error happens
	 */
	reloadScriptPreserveCmdLine(scriptWinTitle := "", titleMatchMode := "2") {
		raii := new AVarValuesRollback("A_DetectHiddenWindows=ON|A_TitleMatchMode=" titleMatchMode)

		if (scriptWinTitle) {
			if (!(WinGetClass(scriptWinTitle) ~= "AutoHotkey|AutoHotkeyGUI")) {
				return 0
			}

			queryEnum := ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId=" WinGet("PID", scriptWinTitle))._NewEnum()
			proc := {}
			if (queryEnum[proc]) {
				static cNeedle := "isO)AutoHotkey.exe""?"
				if (pos := RegExMatch(proc.CommandLine, cNeedle, m)) {
					cmdLine := SubStr(proc.CommandLine, 1, pos + m.Len()) " /restart "
					         . SubStr(proc.CommandLine,    pos + m.Len())
					; logDebug(cmdLine)
					return Run(cmdLine)
				}
			}
			return 0
		}

		if (A_IsCompiled) {
			Reload
			return
		}

		;Reload this script itself
		cmdline := ""
		for i, arg in A_Args {
			cmdline .= arg " "
		}

		;Place /restart switch immediately after the path of interpreter, because it is AutoHotkey's
		;built-in cmd switch and will be removed from new process's A_Args in this case.
		Run(A_AhkPath " /CP65001 /restart " quote(A_ScriptFullPath) " " cmdline)
		ExitApp
	}
}

class WinShell extends StaticClassBase {
;public:
	;File Operations
	static FO_MOVE   := 0x1
       , FO_COPY   := 0x2
       , FO_DELETE := 0x3

	;File Operation Flags
	static FOF_SILENT                := 0x4
	     , FOF_RENAMEONCOLLISION     := 0x8
	     , FOF_NOCONFIRMATION        := 0x10
	     , FOF_ALLOWUNDO             := 0x40
	     , FOF_FILESONLY             := 0x80
	     , FOF_SIMPLEPROGRESS        := 0x100
	     , FOF_NOCONFIRMMKDIR        := 0x200
	     , FOF_NOERRORUI             := 0x400
	     , FOF_NOCOPYSECURITYATTRIBS := 0x800
	     , FOF_NORECURSION           := 0x1000
	     , FOF_NO_CONNECTED_ELEMENTS := 0x2000
	     , FOF_WANTNUKEWARNING       := 0x4000
	     , FOF_NO_UI := WinShell.FOF_SILENT|WinShell.FOF_NOCONFIRMATION|WinShell.FOF_NOERRORUI|WinShell.FOF_NOCONFIRMMKDIR
	     ; , FOF_MULTIDESTFILES := 0x1
	     ; , FOF_WANTMAPPINGHANDLE := 0x20

	Copy(source, dest, flags := "") {
		return WinShell.ShellFileOperation(WinShell.FO_COPY, source, dest, flags)
	}
	Move(source, dest, flags := "") {
		return WinShell.ShellFileOperation(WinShell.FO_MOVE, source, dest, flags)
	}
	Delete(source, flags := "") {
		return WinShell.ShellFileOperation(WinShell.FO_DELETE, source, "", flags)
	}

	;NOTE: any file path in fSource and fTarget which is not fully qualified absolute paths will be skipped. An attempt to
	;convert path to absolute is performed though, but for fTarget this is not always possible because it is not required
	;to exist before ShellFileOperation completes its work.
	;Although fSource and fTarget can be arrays, only the single first item from the arrays will be processed for now
	;(i.e. operation on multiple files/folders in a single call to this function is not supported)
	ShellFileOperation(fileOp, fSource, fTarget := "", flags := 0x0, hWnd := 0x0) {
		sourceFilesCount := 0
		destFilesCount := 0
		fSource := WinShell.preprocessPathSpec(fSource, false, sourceFilesCount)
		fTarget := WinShell.preprocessPathSpec(fTarget, true, destFilesCount)

		if (!fSource || !fileOp || ((fileOp != WinShell.FO_DELETE) && !fTarget)) {
			logCritical("Abort file operation: invalid parameters")
			return false
		}

		;Alter initial flags by adding useful flags if not already specified
		flags |= WinShell.FOF_ALLOWUNDO
		; if (destFilesCount >= 2)
		; 	flags |= WinShell.FOF_MULTIDESTFILES
		if (fileOp = WinShell.FO_DELETE)
			flags |= WinShell.FOF_WANTNUKEWARNING

		fSource := WinShell.postprocessPathSpec(fSource)
		fTarget := WinShell.postprocessPathSpec(fTarget)

		VarSetCapacity(SHFILEOPSTRUCT, 60, 0)
		NextOffset := NumPut(hWnd, &SHFILEOPSTRUCT)
		NextOffset := NumPut(fileOp, NextOffset+0)
		NextOffset := NumPut(&fSource, NextOffset+0)
		NextOffset := NumPut(&fTarget, NextOffset+0)
		NextOffset := NumPut(flags, NextOffset+0, 0, "Short")
		;NOTE: doesn't work as expected without explicit appending of W/A suffix to function name
		code := DllCall("Shell32\SHFileOperation" . (A_IsUnicode ? "W" : "A"), "Ptr",&SHFILEOPSTRUCT)
		anyOperationAborted := NumGet(NextOffset+0)
		return !anyOperationAborted
	}

;private:
	static cDelimiterChar := "|"

	isAbsolutePath(path) {
		return path ~= "i)[a-z]:"
	}

	;Create single delimited string from array of paths, try convert each path to absolute and skip those where this try failed
	preprocessPathSpec(pathSpec, ensureOnlyIsAbsolute := false, ByRef filesCount := 0) {
		filesCount := 0
		if (IsObject(pathSpec)) {
			;convert array of file names to string
			str := ""
			for k, path in pathSpec {
				fullPath := ensureOnlyIsAbsolute ? (WinShell.isAbsolutePath(path) ? path : "") : GetAbsolutePath(path)
				if (fullPath) {
					str .= fullPath . WinShell.cDelimiterChar
					++filesCount
				} else {
					logWarn("Skip file {} because it cannot be resolved to absolute path", path)
				}
			}
			pathSpec := str
		} else {
			if (ensureOnlyIsAbsolute) {
				pathSpec := WinShell.isAbsolutePath(pathSpec) ? (pathSpec . WinShell.cDelimiterChar) : ""
			} else {
				pathSpec := GetAbsolutePath(pathSpec)
				if (pathSpec) {
					pathSpec .= WinShell.cDelimiterChar
				}
			}

			if (pathSpec) {
				filesCount := 1
			}
		}

		if (pathSpec)
			pathSpec := SubStr(pathSpec, 1, InStr(pathSpec, WinShell.cDelimiterChar)) ;NOTE: only 1 file is supported for now
		else
			logWarn("Skip file {} because it cannot be resolved to absolute path", pathSpec)

		return pathSpec
	}
	;Prepare path for DllCall
	postprocessPathSpec(pathSpec) {
		cDelimiterCharCode := Ord(WinShell.cDelimiterChar)
		if (SubStr(pathSpec, 0) != WinShell.cDelimiterChar)
			pathSpec := pathSpec . WinShell.cDelimiterChar

		char_size := t_size()
		char_type := t_char()

		;Replace all delimiters with NULL character according to requirements of SHFileOperation
		Loop % StrLen(pathSpec)
			if (NumGet(pathSpec, (A_Index-1)*char_size, char_type) = cDelimiterCharCode)
				NumPut(0, pathSpec, (A_Index-1)*char_size, char_type)

		return pathSpec
	}
}