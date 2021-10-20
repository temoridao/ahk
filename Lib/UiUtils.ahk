/**
 * @file
 * Utitility functions related to GUI
 *
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

#include %A_LineFile%\..\StaticClassBase.ahk

class UiUtils extends StaticClassBase {
	setExplorerTheme(hWnd, e := "Explorer") {
		Return DllCall("UxTheme.dll\SetWindowTheme", "Ptr", hWnd, "WStr", e, "Ptr", 0)
	}

	/**
	 * Get ListView's column number under mouse cursor
	 *
	 * This function must be called from ListView's associated g-label fired on mouse event.
	 *
	 * @param   hWnd  ListView's HWND
	 *
	 * @return  Column number (starting from 1) where the ListView's event occured. Zero if no items
	 *          found under cursor
	 */
	LV_SubitemHitTest(hWnd) {
		VarSetCapacity(POINT, 8, 0)
		; Get the current cursor position in screen coordinates
		DllCall("User32.dll\GetCursorPos", "Ptr", &POINT)
		; Convert them to client coordinates related to the ListView
		DllCall("User32.dll\ScreenToClient", "Ptr", hWnd, "Ptr", &POINT)
		; Create a LVHITTESTINFO structure (see below)
		VarSetCapacity(LVHITTESTINFO, 24, 0)
		; Store the relative mouse coordinates
		NumPut(NumGet(POINT, 0, "Int"), LVHITTESTINFO, 0, "Int")
		NumPut(NumGet(POINT, 4, "Int"), LVHITTESTINFO, 4, "Int")
		; Send a LVM_SUBITEMHITTEST to the ListView
		SendMessage, LVM_SUBITEMHITTEST := 0x1039, 0, &LVHITTESTINFO, , ahk_id %hWnd%
		; If no item was found on this position, the return value is -1
		If (ErrorLevel = -1) {
			Return 0
		}
		; Get the corresponding subitem (column)
		Subitem := NumGet(LVHITTESTINFO, 16, "Int") + 1
		Return Subitem

		/*
		typedef struct _LVHITTESTINFO {
		  POINT pt;
		  UINT  flags;
		  int   iItem;
		  int   iSubItem;
		  int   iGroup;
		} LVHITTESTINFO, *LPLVHITTESTINFO;
		*/
	}

	LV_SetRowHeight(height) {
		;By setting fake image list to List View we get increased row height
		IconWidth    :=  2
		IconHeight   := height ;This will be a row height of the List View
		IconBitDepth := 24
		InitialCount :=  1 ;The starting number of icons available in image list
		GrowCount    :=  1
		imgList := DllCall("ImageList_Create", "Int",IconWidth, "Int",IconHeight, "Int",IconBitDepth, "Int",InitialCount, "Int",GrowCount)
		LV_SetImageList(imgList, 1) ;0 for large icons, 1 for small icons
		return imgList
	}

	focusedControlHwnd() {
		GuiControlGet, controlInFocus, Focus
		ControlGet, hWnd, HWND,, %controlInFocus%
		return hWnd
	}
}
