/**
 * Description:
 *    Utitility functions related to UI elements
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
SetExplorerTheme(hWnd, e := "Explorer") {
	Return DllCall("UxTheme.dll\SetWindowTheme", "Ptr", hWnd, "WStr", e, "Ptr", 0)
}