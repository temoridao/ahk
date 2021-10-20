/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\
	#include ShellEventsWatcher.ahk
	#include UiUtils.ahk
	#include Serializable.ahk
	#include CommonUtils.ahk

#include %A_LineFile%\..\..\3rdparty\
	#include CodeQuickTester\lib\WinEvents.ahk
	#include Lib\AutoXYWH.ahk

/**
 * Collects titles of closing explorer.exe's windows and provides UI to access this data
 *
 * Also has functionality to dump collected data to .json file and load it later. See usage example
 * for details.
 *
 * Usage Example:
 * @code{.ahk}
   #include <ClosedWindowsCollector>

   hotkeyReopenWindow         := "#w"  ;Win+W
   , hotkeyShowSavedWindowsUi := "#+w" ;Win+Shift+W

   global g_collector := new ClosedWindowsCollector(hotkeyReopenWindow, hotkeyShowSavedWindowsUi)
   OnExit("exitFunc") ;Serialize data to .json file upon script exit

   g_collector.start() ;Start monitoring of explorer.exe windows closing and save some info about them for reference/restoring later
   ;Now open, close some folders and try above hotkeys

   ;--------------------------End of auto-execute section--------------------------

   exitFunc() {
   	g_collector.serialize()
   }
 * @endcode
 */
class ClosedWindowsCollector extends Serializable {
;public:

	/**
	 * The constructor
	 *
	 * @param   keySequenceReopenSavedWindow        The hotkey to reopen most recent saved window
	 * @param   keySequenceShowSavedWindowsSummary  The hotkey to show saved windows summary UI
	 * @param   savedWindowsCountLimit              The maximum windows count to remember. After
	 *                                              reaching this limit, the least recently saved
	 *                                              window's info will be overridden
	 */
	__New(keySequenceReopenSavedWindow, keySequenceShowSavedWindowsSummary, savedWindowsCountLimit := 10) {
		this.m_keySequenceReopenSavedWindow       := keySequenceReopenSavedWindow
		this.m_keySequenceShowSavedWindowsSummary := keySequenceShowSavedWindowsSummary
		this.m_savedWindowsCountLimit             := savedWindowsCountLimit

		Serializable.deserialize(this, this.persistentStateFilename())
	}

	serialize() {
		Serializable.serialize(this.persistentStateFilename(), this, "m_savedWindowsInfo")
	}

	__Delete() {
		this.stop()
	}

	start() {
		if (this.m_isRunning) {
			return
		}

		eventDestroy := ShellEventsWatcher.HSHELL_WINDOWDESTROYED
		this.m_windowDestroyEventsWatcher := new ShellEventsWatcher({(eventDestroy) : [ObjBindMethod(this.base, "onWinDestroy", &this)]})

		; Binding to "this.base", e.g. reference to class, not an instance object.
		; This will not hold an additional reference to "this" object in the resulting BoundFunc object stored
		; inside Hotkey command and allows ClosedWindowsCollector::__Delete() metafunction to be called on destruction.
		; See https://www.autohotkey.com/boards/viewtopic.php?p=235969#p235969 for detailed explanation.
		Hotkey(this.m_keySequenceReopenSavedWindow, ObjBindMethod(this.base, "restoreClosedFileExplorerWindow", &this))
		HotKey(this.m_keySequenceShowSavedWindowsSummary, ObjBindMethod(this.base, "showSavedWindowsSummary", &this), "T2")

		this.m_isRunning := true
	}

	stop() {
		if (!this.m_isRunning) {
			return
		}

		Hotkey(this.m_keySequenceReopenSavedWindow,, "Off")
		Hotkey(this.m_keySequenceShowSavedWindowsSummary,, "Off")
		this.m_windowDestroyEventsWatcher.stop()
		this.m_isRunning := false
	}

	setKeySequence(keySequenceReopenSavedWindow := "", keySequenceShowSavedWindowsSummary := "") {
		if (!keySequenceReopenSavedWindow && !keySequenceShowSavedWindowsSummary) {
			return
		}

		wasRunning := this.m_isRunning
		this.stop()
		this.m_keySequenceReopenSavedWindow := keySequenceReopenSavedWindow ? keySequenceReopenSavedWindow : this.m_keySequenceReopenSavedWindow
		this.m_keySequenceShowSavedWindowsSummary := keySequenceShowSavedWindowsSummary ? keySequenceShowSavedWindowsSummary : this.m_keySequenceShowSavedWindowsSummary
		if (wasRunning) {
			this.start()
		}
	}

	lastOpenedPath() {
		return this.m_savedWindowsInfo[this.m_savedWindowsInfo.Length()].path
	}

	keySequenceReopenSavedWindow() {
		return this.m_keySequenceReopenSavedWindow
	}

	keySequenceShowSavedWindowsSummary() {
		return this.m_keySequenceShowSavedWindowsSummary
	}

	isRunning() {
		return this.m_isRunning
	}

;private:
	class SavedWindowsSummaryUi
	{
	;public:
		__New(parent) {
			this.m_parent := parent

			Gui New, +hWndhWnd +Resize
			WinEvents.Register(hWnd, this)
			this.m_hWnd := hWnd
			Gui Font,, % "Courier New"
			Gui Font,, % "Fira Code"

			Gui Add, ListView, +hWndhWnd x0 y0 w1000 h560 NoSortHdr AltSubmit +LV0x10000, Dir & Path|Geometry [X, Y; WxH]
			this.m_hWndListView := hWnd
			functor := this.onListItemEvent.Bind(this)
			GuiControl, +g, %hWnd%, %functor%
			UiUtils.setExplorerTheme(hWnd)

			; `yp` positions 0x0 size button at the y-coordinate of the previous control (tree view) to
			; prevent adding visual margin (Gui Margin) for invisible fake button
			Gui Add, Button, Hidden Default +hWndhWnd w0 h0 yp, FakeButtonToReceiveEnterPress
			functor := this.onEnterPressed.Bind(this)
			GuiControl, +g, %hWnd%, %functor%

			this.refresh()
		}

		onListItemEvent() {
			if (A_GuiEvent = "DoubleClick") {
				this.openWindow(A_EventInfo)
			} else if (A_GuiEvent = "K") { ; Key press event
				keyName := GetKeyName(Format("vk{:x}", A_EventInfo))
				if (keyName = "c" && GetKeyState("Ctrl", "P")) { ; Ctrl+C combination
					LV_GetText(text, LV_GetNext())
					; OutputDebug % "Selection: " text
					Clipboard := this.cleanupPath(text)
					; Wait for key release to avoid repetitive invocation of this function and copying to clipboard every time
					KeyWait % keyName
				}
			}
		}
		onEnterPressed() {
			this.openWindow(LV_GetNext(0, "Focused"))
		}
		openWindow(listViewRowIndex) {
			parent := this.m_parent
			parentIndex := parent.m_savedWindowsInfo.Length() - listViewRowIndex + 1 ; this conversion needed because list view displays windows in reverse order, see __New()
			ClosedWindowsCollector.restoreClosedFileExplorerWindow(&parent, parentIndex)
			WinActivate("ahk_id" this.m_hWnd)
		}

		title() {
			return Format("[{}] Recently Closed (most recent at the top) — {}, Enter, double click to reopen window from list; "
			  	       . "{} to show this dialog"
			  , this.m_parent.m_savedWindowsInfo.Length()
			  , HotUtils.hotkeyToDisplayString(this.m_parent.m_keySequenceReopenSavedWindow)
			  , HotUtils.hotkeyToDisplayString(this.m_parent.m_keySequenceShowSavedWindowsSummary))
		}
		;Display UI and block current thread until UI window closed
		exec() {
			LV_ModifyCol(1, "Auto") ; Auto expand first column to fit content
			LV_ModifyCol(2, 200)
			Gui Show,, % this.title()
			Gui +AlwaysOnTop
			f := this.updateWindowStatus.Bind(this)
			SetTimer(f, 100)
			WinWaitClose % "ahk_id" this.m_hWnd
			SetTimer(f, "Delete")
		}

		cleanupPath(dirtyPath) {
			return RegExReplace(dirtyPath, "(^.+  \| )|(\Q" this.cExistentWindowTitlePrefix "\E)")
		}

		;Updates presence of marker near existent folders' path
		updateWindowStatus() {

			hWnd := this.m_hWnd
			if (!WinExist("ahk_id" hWnd)) {
				return
			}

			SetTitleMatchMode 3
			Gui %hWnd%:Default

			WinSetTitle % this.title()
			Loop % LV_GetCount() {
				LV_GetText(text, A_Index)

				hasMarker := InStr(text, this.cExistentWindowTitlePrefix)
				cleanPath := RegExReplace(text, "(^.+  \| )|(\Q" this.cExistentWindowTitlePrefix "\E)") ;Remove all from beginning of string up to "|" delimiter AND this.cExistentWindowTitlePrefix
				if (WinExist(cleanPath)) {
					if (!hasMarker) {
						LV_Modify(A_Index, "Col1", StrReplace(text, "| ", "| " this.cExistentWindowTitlePrefix))
					}
				} else {
					if (hasMarker) {
						LV_Modify(A_Index, "Col1", StrReplace(text, this.cExistentWindowTitlePrefix))
					}
				}
			}
		}

		refresh() {
			hWnd := this.m_hWnd
			Gui %hWnd%: Default
			focusedRow := LV_GetNext(0, "Focused")
			LV_Delete()

			raii := new AVarValuesRollback("A_TitleMatchMode=3")
			i := this.m_parent.m_savedWindowsInfo.Length() + 1
			while (--i) {
				title := this.m_parent.m_savedWindowsInfo[i].path
				g := this.m_parent.m_savedWindowsInfo[i].geometry
				winGeometryText := Format("[{1}, {2}; {3}x{4}]", g.x, g.y, g.width, g.height)
				SplitPath(title, dirName), dirName := dirName ? dirName : title
				LV_Add(""
						;Width    : -15 -> left aligned minimum width of string
						;Precision: .15 -> maximum characters to be printed
						;NOTE: monospace font should be used in GUI for pleasant visual result
					, Format("{:-15.15s}  | {}", dirName, title)
					, winGeometryText)
			}

			if (focusedRow) {
				LV_Modify(focusedRow, "Focus Select")
			}
		}

		GuiEscape() {
			this.GuiClose()
		}

		GuiClose() {
			WinEvents.Unregister(this.m_hWnd)
			Gui Destroy
		}

		GuiSize() {
			AutoXYWH("wh", this.m_hWndListView)
		}

		static cExistentWindowTitlePrefix := "[🔆] "

		m_parent := {}
		m_hWnd := ""
		m_hWndListView := ""
	}

	onWinDestroy(thisObjAddress, hWnd) {
		ListLines Off
		DetectHiddenWindows On

		winTitle := "ahk_id" hWnd
		title := WinGetTitle(winTitle)
		; Skip folders with "special" names like "Downloads", "Documents", etc.
		; They do not have path in the window title so not have a backslash too. Also skip unwanted wnd classes
		if (!InStr(title, "\") || IfNotIn(WinGetClass(winTitle), "CabinetWClass,ExploreWClass")) {
			return
		}

		this := Object(thisObjAddress)
		if (index := this.hasTitle(title)) {
			; Push window's info to the top of stack
			this.m_savedWindowsInfo.Push({"path" : this.m_savedWindowsInfo.RemoveAt(index).path, "geometry" : CommonUtils.getWinGeometry(winTitle)})
			this.m_ui.refresh()
			return
		}

		if (this.m_savedWindowsInfo.Length() = this.m_savedWindowsCountLimit) {
			this.m_savedWindowsInfo.RemoveAt(1)
		}

		; OutputDebug % "Destroyed: ``" title "`` -> info: " ObjToString(CommonUtils.getWinGeometry(winTitle))
		this.m_savedWindowsInfo.Push({"path" : title, "geometry" : CommonUtils.getWinGeometry(winTitle)})
		this.m_ui.refresh()
	}

	restoreClosedFileExplorerWindow(thisObjAddress, row := 0) {
		this := object(thisObjAddress)

		if (this.m_savedWindowsInfo.Length()) {
			failedToOpenList :=  row > 0 ? CommonUtils.reopenExplorerWindow(this.m_savedWindowsInfo[row].path, this.m_savedWindowsInfo[row].geometry, "", "A") : CommonUtils.reopenExplorerWindows([this.m_savedWindowsInfo.Pop()], "A")
			if (failedToOpenList.Length()) {
				CommonUtils.ShowToolTip("Failed to restore folder: " failedToOpenList[1], 5000)
			}
		}
		if (this.m_ui) {
			this.m_ui.refresh()
		}
	}

	showSavedWindowsSummary(thisObjAddress) {
		this := object(thisObjAddress)
		if (this.m_ui && WinExist("ahk_id" this.m_ui.m_hWnd)) {
			return WinRestore(), WinActivate()
		}

		this.m_ui := new ClosedWindowsCollector.SavedWindowsSummaryUi(this)
		this.m_ui.exec()
		this.m_ui := ""
	}

	hasTitle(title) {
		titles := []
		for each, value in this.m_savedWindowsInfo {
			titles.Push(value.path)
		}

		return HasVal(titles, title)
	}

	m_ui                                 := "" ;instance of WindowGroupsSummaryUi class
	m_isRunning                          := false
	m_savedWindowsInfo                   := []
	m_savedWindowsCountLimit             := 0
	m_windowDestroyEventsWatcher         := {}
	m_keySequenceReopenSavedWindow       := "" ; hotkey to open recent window
	m_keySequenceShowSavedWindowsSummary := "" ; hotkey to show quick summary of closed windows which can be restored
}
