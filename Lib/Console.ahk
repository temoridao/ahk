/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/
/**
 * Write text to win32 console
 *
 * @code{.ahk}
 * #include <Console> ;Assuming Console.ahk in your library
 * F12::Console.PrintLine("Hello, I am written to console")
 * @endcode
*/
class Console {
;public:
	Print(ByRef vText := "") {
		this.StdOut.Write(vText)
		this.StdOut.Read(0) ;flush the write buffer
	}

	PrintLine(ByRef vText := "") {
		this.Print(vText "`n")
	}

	Hide() {
		WinHide % this.consoleWin()
	}
	Show() {
		DetectHiddenWindows ON
		WinShow % this.consoleWin()
	}
	Visible() {
		return DllCall("IsWindowVisible", "Ptr", this.consoleHwnd())
	}

;private:
	static __self := new Console()
	#include %A_LineFile%\..\SuperGlobalSingleton.ahk
	__InitSingleton() {
		if (!DllCall("AllocConsole")) {
			Msgbox % "Failed to allocate console: " A_LastError
		}
		this.StdOut := FileOpen("*", "w `n")
	}

	consoleHwnd() {
		WinGet hWnd, ID, % "ahk_class ConsoleWindowClass ahk_pid" DllCall("GetCurrentProcessId")
		return hWnd
	}
	consoleWin() {
		return "ahk_id" this.consoleHwnd()
	}
}
