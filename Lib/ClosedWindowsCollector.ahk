/**
 * Description:
 *    %TODO%
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
#include %A_LineFile%\..\
	#include ShellEventsWatcher.ahk
	#include UiUtils.ahk
	#include Serializable.ahk


#include %A_LineFile%\..\..\3rdparty\
	#include CodeQuickTester\lib\WinEvents.ahk
	#include Lib\Anchor.ahk

class ClosedWindowsCollector extends Serializable {
;public:
	/**
	* After reaching \p savedWindowsCountLimit limit, the least recently saved window's info will be overriden
	*/
	__New(keySequenceReopenSavedWindow, keySequenceShowSavedWindowsSummary, savedWindowsCountLimit := 10) {
		this.m_keySequenceReopenSavedWindow := keySequenceReopenSavedWindow
		this.m_keySequenceShowSavedWindowsSummary := keySequenceShowSavedWindowsSummary
		this.m_savedWindowsCountLimit := savedWindowsCountLimit

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

		this.m_windowDestroyEventsWatcher := new ShellEventsWatcher({(ShellEventsWatcher.HSHELL_WINDOWDESTROYED) : [ObjBindMethod(this.base, "onWinDestroy", &this)]})

		; Binding to "this.base", e.g. reference to class, not an instance object.
		; This will not hold an additional reference to "this" object in the resulting BoundFunc object stored
		; inside Hotkey command and allows ClosedWindowsCollector::__Delete() metafunction to be called on destruction.
		; See https://www.autohotkey.com/boards/viewtopic.php?p=235969#p235969 for detailed explanation.
		Hotkey(this.m_keySequenceReopenSavedWindow, ObjBindMethod(this.base, "restoreClosedFileExplorerWindow", &this))
		HotKey(this.m_keySequenceShowSavedWindowsSummary, ObjBindMethod(this.base, "showSavedWindowsSummary", &this))

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

			Gui Add, ListView, +hWndhWnd w800 h500 NoSortHdr, Path|Geometry [X, Y; WxH]
			this.m_hWndListView := hWnd
			functor := this.onListItemEvent.Bind(this)
			GuiControl, +g, %hWnd%, %functor%
			SetExplorerTheme(hWnd)

			Gui Add, Button, Hidden Default +hWndhWnd w0 h0 yp, FakeButtonToReceiveEnterPress ; `yp` positions 0x0 size button at the y-coordinate of the previous control (tree view) to prevent adding visual margin (Gui Margin) for invisible fake button
			functor := this.onEnterPressed.Bind(this)
			GuiControl, +g, %hWnd%, %functor%

			this.refresh()
		}

		onListItemEvent() {
			this.openWindow(A_EventInfo)
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

		;Display UI and block current thread until UI window closed
		exec() {
			LV_ModifyCol(1, "Auto") ; Auto expand first column to fit content
			Gui Show,, Recently Closed (most recent at the top) — [Win+W]
			Gui +AlwaysOnTop
			f := this.updateWindowStatus.Bind(this)
			SetTimer(f, 100)
			WinWaitClose % "ahk_id" this.m_hWnd
			SetTimer(f, "Delete")
		}

		;Updates presence of '[✘]' marker near non-existent path
		updateWindowStatus() {
			hWnd := this.m_hWnd
			if (!WinExist("ahk_id" hWnd)) {
				return
			}

			SetTitleMatchMode 3
			Gui %hWnd%:Default

			Loop % LV_GetCount() {
				LV_GetText(text, A_Index)
				if (WinExist(cleanPath := RegExReplace(text, "\Q" this.cExistentWindowTitlePostfix "\E"))) {
					if (cleanPath == text)
						LV_Modify(A_Index, "Col1", cleanPath . this.cExistentWindowTitlePostfix)
				} else {
					if (cleanPath != text)
						LV_Modify(A_Index, "Col1", cleanPath)
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
				LV_Add("", title, winGeometryText)
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
			Anchor(this.m_hWndListView, "wh")
		}

		static cExistentWindowTitlePostfix := " [🔆]"

		m_parent := {}
		m_hWnd := ""
		m_hWndListView := ""
	}

	onWinDestroy(thisObjAddress, hWnd) {
		ListLines Off
		DetectHiddenWindows On

		winTitle := "ahk_id" hWnd
		title := WinGetTitle(winTitle)
		if (!InStr(title, "\") || IfNotIn(WinGetClass(winTitle), "CabinetWClass,ExploreWClass")) { ; Skip folders with "special" names like "Downloads", "Documents", etc. They do not have path in the window title so not have a backslash too. Also skip unwanted wnd classes
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

		; OutputDebug % "Destroyed: ``" title "`` -> info: " CommonUtils.ObjToString(CommonUtils.getWinGeometry(winTitle))
		this.m_savedWindowsInfo.Push({"path" : title, "geometry" : CommonUtils.getWinGeometry(winTitle)})
		this.m_ui.refresh()
	}

	restoreClosedFileExplorerWindow(thisObjAddress, row := 0) {
		this := object(thisObjAddress)

		if (this.m_savedWindowsInfo.Length()) {
			failedToOpenList :=  row > 0 ? CommonUtils.reopenExplorerWindow(this.m_savedWindowsInfo[row].path, this.m_savedWindowsInfo[row].geometry) : CommonUtils.reopenExplorerWindows([this.m_savedWindowsInfo.Pop()])
			if (failedToOpenList.Length()) {
				MsgBox % 262144 + 48, Failed To Open Folder, % failedToOpenList[1]
			}
		}
	}

	showSavedWindowsSummary(thisObjAddress) {
		this := object(thisObjAddress)
		this.m_ui := new ClosedWindowsCollector.SavedWindowsSummaryUi(this)
		this.m_ui.exec()
		this.m_ui := ""
	}

	hasTitle(title) {
		titles := []
		for each, value in this.m_savedWindowsInfo {
			titles.Push(value.path)
		}

		return CommonUtils.HasValue(titles, title)
	}

	m_ui := "" ;instance of WindowGroupsSummaryUi class
	m_savedWindowsInfo := []
	m_savedWindowsCountLimit := 0
	m_windowDestroyEventsWatcher := {}
	m_keySequenceReopenSavedWindow := "" ; hotkey to open recent window
	m_keySequenceShowSavedWindowsSummary := "" ; hotkey to show quick summary of closed windows which can be restored
	m_isRunning := false
}
