# Starter.ahk
Smart launcher for your scripts with ability to compile/combine all of them into single portable _Starter.exe_ by one click!

#### How to Use:
1. Clone this repo `git clone --recursive https://github.com/temoridao/ahk` or [download latest self-contained snapshot](https://github.com/temoridao/ahk/releases)
2. Double click on _Starter.ahk_ — you'll see a message box prompting you for the list of scripts to launch. Press OK and _Starter.txt_ will be opened ready for adding paths to your scripts or even whole directories (they will be scanned for `*.ahk` files, non-recursively)
3. Add your favorite scripts, save .txt file and launch _Starter.ahk_ again
4. Done!

Optional: If you compile this script (with `Compile Script` entry from context menu, or in tray menu), it will embed all scripts you specified in the .txt (marked with `~`, see below) into _Starter.exe_'s resources (thanks to new Ahk2Exe). Now you have all your scripts in a single portable _Starter.exe_ (which can be copied to USB stick, etc).

#### List of Features
* Launch and centrally control the scripts you specified in _Starter.txt_ (folders supported). Tray icons will be automatically hidden (even after restarting explorer.exe, see `ProcessTerminationWatcher.ahk` for details)
* Compile it to get _Starter.exe_ with all scripts embedded (you should mark them for compilation with `~` symbol at the beginning of the path, as explained in _Starter.txt_ on first launch)
* Individual control of each script available in right click context menu of tray icon
* List of supported command line switches available in the _Config Section_ (top part of script). Some of them are disabled by default, such as `--elevate`, or disabled only for compiled version, such as `--show-tray-tip`. Feel free to experiment.
* Custom tray icon will be automatically picked up if it located near script and has name of the script plus extension, f.e. Starter.ahk.ico (png, jpg supported). Or you can pass your own path, see CommonUtils.setupTrayIcon() method
* Custom _Starter.exe_ icon can be specified in Config Section with _@Ahk2Exe-SetMainIcon_ directive (remove space between semicolon and `@` to enable it). By default, an icon named _Starter.exe.ico_ expected
* If you need compression for your executable, place upx.exe near the Ahk2Exe.exe. Also note that compressed executable will have `c` (from **c**ompressed) letter appended to its name by default, f.e. _Starterc.exe_
* Your custom code can be added at the bottom of auto-execute section or to any optional injection file(s) (need to manually create them) for compiled, non-compiled or both forms of _Starter_ (see comments in the script). This is a convenient method of applying common logic for all your scripts at once. For example, add the following code at the bottom of auto-execute section (or paste into one of injection files):

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
	return HasVal(cHotkeysSuspendApps, WinGet("ProcessName", "A")) ;NOTE: WinGet() here is a function wrapper around `WinGet` command. See 3rdparty\Lib\Functions.ahk
}
```
This will suspend all controlled scripts whenever Microsoft Remote Desktop or TeamViewer window becomes active and un-suspend them when those windows become inactive (useful if your remote machine also uses AutoHotkey which may interfere with your local machine's hotkeys).

#### Builit-in Hotkeys
* **Win+Shift+\`** (my favorite!) — restart **any AutoHotkey script** (controlled by Starter or not) if its window currently active. If previous check failed, then active window's title analyzed if it contains name of **any** script currently running on the system and, if match found, reloads it — extremely useful for debugging purposes (if your text editor contains name of currently edited script in the title, which is true for any sane editor)
* **Win+Shift+Esc** — restart all controlled scripts
* **Win+Shift+S** / **Win+Shift+Alt+S** — toggle suspend state of managed/all currently running AutoHotkey scripts on the system  (double press `S` while holding Win and Shift send original keystroke Win+Shift+S to be able to launch Windows built-in Snip & Sketch tool. See `HandleMultiPressHotkey()` in `HotUtils.ahk` for details)

# TrayIconsSummary.ahk
Show simple Gui with a brief summary of taskbar's tray icons

# Licensing
All code in this repository is unlicensed (dedicated to Public Domain, see UNLICENSE.txt), except `3rdparty` directory where scripts/submodules usually have their own permissive license notices.
