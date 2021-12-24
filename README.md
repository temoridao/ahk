# General highlights
See [Lib](https://github.com/temoridao/ahk/tree/master/Lib) folder for useful libraries used by scripts in the root of this repository. The majority of library code is documented and contains ready-to-use examples

# Starter.ahk
Smart launcher for your scripts with ability to compile/combine all of them into single portable _Starter.exe_ by one click!

#### How to Use:
1. Clone this repo `git clone --recursive https://github.com/temoridao/ahk` or [download latest self-contained snapshot](https://github.com/temoridao/ahk/releases)
2. Double click on _Starter.ahk_ — you'll see a message box prompting you for the list of scripts to launch. Press OK and _Starter.txt_ will be opened ready for adding paths to your scripts or even whole directories (they will be scanned for `*.ahk` files, non-recursively)
3. Add your favorite scripts, save Starter.txt file and launch _Starter.ahk_ again
4. Done!

Optional step: If you compile this script (with `Compile Script` entry from context menu, or in tray menu), it will embed all scripts you specified in the _Starter.txt_ (marked with `~`, see below) into _Starter.exe_'s resources (thanks to new Ahk2Exe compiler directives). Now you have all your scripts in a single portable _Starter.exe_ (which can be copied and launched on another machine or USB stick, etc).

#### List of Features
* Launch and centrally control the scripts you specified in _Starter.txt_ or pass via command line or drag & drop in explorer (folders supported). Tray icons will be automatically hidden (even after restarting explorer.exe, see `ProcessTerminationWatcher.ahk` for details)
* Compile _Starter.ahk_ to get _Starter.exe_ with all marked scripts embedded inside. Scripts should be marked for inclusion with `~` symbol at the beginning of the path, as explained in _Starter.txt_ on first launch. Alternatively hold `Ctrl` key while dropping scripts onto _Starter.ahk_ from windows explorer or pass `--compile-package` command line parameter
* Individual control of each script available in right click context menu of tray icon
* List of supported command line switches with default values are available in the _Config Section_ (top part of the script). Some of them are disabled by default, such as `--elevate`, or disabled only for compiled version, such as `--show-tray-tip`. 
* Custom tray icon will be automatically picked up if it located near script and has name of the script plus extension, f.e. Starter.ahk.ico (png, jpg supported). Or you can pass your own path, see `CommonUtils.setupTrayIcon()` method
* Custom _Starter.exe_ icon can be specified in Config Section with _@Ahk2Exe-SetMainIcon_ directive (remove space between semicolon and `@` to enable it). By default, an icon named _Starter.exe.ico_ expected
* If you need compression for your executable, place `upx.exe` near the `Ahk2Exe.exe`. Also note that compressed executable will have `c` (from **c**ompressed) letter appended to its name by default, f.e. _Starterc.exe_
* _Starter.ahk_ supports various command line options. See comments at the top part of the script for brief explanation what they do
* Your custom code can be added at the bottom of auto-execute section or inside any of optional injection file(s) (need to manually create them beforehand) for compiled, non-compiled or both forms of _Starter_ (`Starter_injection.ahk` is a recommended ready-to-use template for script injection). This is a convenient method of applying common logic for all your scripts at once. For example, add the following code at the bottom of auto-execute section (or paste into one of injection files):

```AutoHotkey
#include <ShellEventsWatcher> ;ShellEventsWatcher.ahk can be found in Lib folder near Starter.ahk

event := ShellEventsWatcher.HSHELL_WINDOWACTIVATED
global g_shellEventsWatcher := new ShellEventsWatcher({(event): ["updateSuspension"]})

updateSuspension(activatedHwnd) {
	for i, pid in g_scriptsPids
		AhkScriptController.setSuspend("ahk_pid" pid, shouldSuspend())
}
shouldSuspend() {
	static cHotkeysSuspendApps := ["mstsc.exe", "TeamViewer.exe"]
	return HasVal(cHotkeysSuspendApps, WinGet("ProcessName", "A")) ;WinGet() here is a function wrapper around `WinGet` command. See 3rdparty\Lib\Functions.ahk
}
```
This will suspend all controlled scripts whenever Microsoft Remote Desktop or TeamViewer window becomes active and unsuspend them when that window becomes inactive (it is useful to suspend scripts on your local machine if your remote machine also uses AutoHotkey and interferes with your local machine's hotkeys).

#### Built-in Hotkeys
* **Win+Shift+\`** (my favorite!) — restart **any AutoHotkey script** (controlled by Starter or not) if its window currently active. If previous check failed, then active window's title analyzed if it contains name of **any** script currently running on the system and, if match found, reloads it — extremely useful for debugging purposes (if your text editor contains name of currently edited script in the title, which is true for any sane editor)
* **Win+Shift+Esc** — restart all scripts managed by Starter
* **Win+Shift+S** / **Win+Shift+Alt+S** — toggle suspend state of managed/all currently running AutoHotkey scripts on the system

# TrayIconsSummary.ahk
Show simple Gui with a brief summary of taskbar's tray icons

# Licensing
All code in this repository is unlicensed (dedicated to Public Domain, see UNLICENSE.txt), except `3rdparty` directory where scripts/submodules usually have their own permissive license notices.
