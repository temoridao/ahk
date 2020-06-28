# Starter.ahk
Smart launcher for your scripts with optional ability to compile (combine) all of them into single portable `Starter.exe` executable by one click!

#### How to Use:
1. Clone this repo `git clone --recursive https://github.com/temoridao/ahk` or [download latest snapshot](https://github.com/temoridao/ahk/releases)
2. Double click on `Starter.ahk` — you'll see a message with simple instruction prompting you for the list of scripts to launch. Press OK and `Starter.txt` file will be opened ready for adding paths to your scripts or even whole directories (they scanned for `*.ahk` files)
3. Add you favorite scripts, save .txt file and launch `Starter.ahk` again
4. Done!

5. Optional: right click on tray icon > `Compile Starter.exe` will create portable `Starter.exe` with all your scripts built-in (marked with `~`, see below)

#### Full List of Features
* Launch and centrally control the scripts you specified in Starter.txt (folders supported). Tray icons will be automatically hidden (even after restarting explorer.exe, see `ProcessTerminationWatcher.ahk` for details)
* Right click on tray icon > `Compile Starter.exe` and you'll get single portable `Starter.exe` with all scripts built-in (you should mark them for compilation with `~` symbol at the beginning of the path, detailed explanation available in `Starter.txt` on first launch).
NOTE: don't try to compile it "manually by hand", it will not work as expected, always use tray menu or `--compile-package` switch
* _Win+Shift+Esc_ — restart all controlled scripts
* _Win+Shift+\`_ (my favorite!) — restart **any AHK script** (controlled by Starter or not) if its window currently active. AND if previous step failed, checks if active window's title contains name of any script currently running on the system and, if matched, reloads it — extremely useful for debugging purposes (if your text editor contains name of currently edited script in the title, which is true for any sane editor)
* _Win+Shift+S_ / _Win+Shift+Alt+S_ — suspend controlled / all currently running on the system scripts
* _Win+Alt+Esc_ — temporary suspend controlled / all currently running on the system scripts, and automatically restore after specified interval (3 seconds by default)
* Double click on Tray Icon will show Gui with short summary of controlled scripts (individual control of each script available in context menu of tray icon)
* List of supported command line switches available in the Config Section. Some of them are disabled by default, such as `--elevate`, or disabled only for compiled version of Starter, such as `--show-tray-tip`
* Custom tray icon will be automatically picked up if it located near script and has name of the script plus extension, f.e. Starter.ahk.ico (png, jpg supported). Or you can pass your own path, see CommonUtils.setupTrayIcon() method
* Custom `Starter.exe` icon can be specified in Config Section (_@Ahk2Exe-SetMainIcon_ directive)
* If you need compression for your executable, place `upx.exe` near the `Ahk2Exe.exe`. By default compiler copied to %A_AppData%\%A_ScriptName%, but if you manually place it near `Starter.ahk`, the latter takes precedence. Also note that compressed executable has `c` letter appended to its name by default, f.e. `Starterc.exe`
* Your custom code can be added at the bottom of auto-execute section or to any optional injection file(s) (need to manually create them) for compiled, non-compiled or both forms of Starter (see comments in the script). For example, add the following code at the bottom of auto-execute section:

```AutoHotkey
#include <ShellEventsWatcher>

event := ShellEventsWatcher.HSHELL_WINDOWACTIVATED
global g_shellEventsWatcher := new ShellEventsWatcher({(event): ["updateSuspension"]})

updateSuspension(activatedHwnd) {
	for i, pid in g_scriptsPids {
		AhkScriptController.setSuspend("ahk_pid" pid, shouldSuspend())
	}
}
shouldSuspend() {
	static cHotkeysSuspendApps := ["mstsc.exe", "TeamViewer.exe"]
	return CommonUtils.HasValue(cHotkeysSuspendApps, WinGet("ProcessName", "A"))
}
```
This will suspend all controlled scripts whenever Microsoft Remote Desktop or TeamViewer window becomes active and un-suspend all controlled scripts when those windows become inactive (useful if your remote machine also uses AutoHotkey scripts which may interfere with your local machine's hotkeys). You may add this code into some of injection files and get this functionality only in compiled or only in non-compiled version of Starter

# TrayIconsSummary.ahk
Show simple Gui with a brief summary of taskbar's tray icons

# Licensing
All code in this repository is unlicensed (dedicated to Public Domain, see UNLICENSE.txt), except `3rdparty` directory where scripts/submodules usually have their own permissive license notices.
