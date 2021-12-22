/**
 * Description:
 *    Smart launcher for your scripts with optional ability to compile/combine them into
 *    a single portable Starter.exe executable by single click.
 * Requirements:
 *    AutoHotkey v1.1.33+
 * Installation:
 *    git clone --recursive https://github.com/temoridao/ahk
 *        or download latest snapshot here: https://github.com/temoridao/ahk/releases
 *
 *    Launch Starter.ahk and it will create Starter.txt, prompting you for the list of scripts to
 *    control.
 *    After you have done, save .txt file and launch Starter.ahk again. Now you have all your
 *    scripts running under control of Starter.ahk.
 *    Starter.ahk can be compiled into single portable .exe file, containing all your controlled
 *    scripts (either by right click in explorer > Compile Script or with tray menu > Compile Starter.exe).
 *
 *    See README for the list of features and other details: https://github.com/temoridao/ahk#starterahk
 * Links:
 *    GitHub     : https://github.com/temoridao/ahk
 *    Forum Topic: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=77910
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
SetWorkingDir %A_ScriptDir%
ListLines Off
FileEncoding UTF-8-RAW

;{ Config Section
	;       Commented lines below starting with @ are directives for Ahk2Exe compiler
	;              and DIRECTLY AFFECT THE BEHAVIOR of resulting executable.
	;               Do not change these lines unless you know what you do.
	;-------------------------------------------------------------------------------------------------
	;Add scripts to launch here (they will be merged with contents of Starter.txt)
	;Remove '*' chars and space before '@' to also mark script for inclusion into Starter.exe
		; @Ahk2Exe-AddResource *RT_RCDATA *MyCoolScript1.ahk*
		; @Ahk2Exe-AddResource *RT_RCDATA *3rdparty\MyCoolScript2.ahk*
	;-------------------------------------------------------------------------------------------------
	;@Ahk2Exe-Bin Unicode 64*
	;@Ahk2Exe-AddResource *RT_RCDATA %A_AhkPath%, RC_AHKRUNTIME
	; @Ahk2Exe-SetMainIcon %A_ScriptName~\..+$~.exe%.ico
	;@Ahk2Exe-Obey SelfCompilationCommandResult, RunWait %A_AhkPath% "%A_ScriptFullPath%" --compile-package`, "%A_ScriptFullPath%\.."
	;-------------------------------------------------------------------------------------------------

	global Config := { Version : "2.11.0"
		;@Ahk2Exe-SetVersion %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%

		, Elevate               : HasVal(A_Args, "--elevate")
		, ShowTrayTip           : HasVal(A_Args, "--enable-tray-tip") || !A_IsCompiled
		, ChildScriptsMatchMode : GetCmdParameterValue("--child-scripts-match-mode", "name") ; Possible values: "name", "pid"
		, ReloadAllShortcut     : "#+Escape"

		;========================Options for compilation process========================================
		, CompileMe       : !A_IsCompiled && HasVal(A_Args, "--compile-package") || (CommonUtils.isKeyboardKeyPressedDllCall("Ctrl") && scriptsFromCommandLine().Length())
		, UseCompression  : HasVal(A_Args, "--compress-package")
		, ProductName     : GetCmdParameterValue("--product-name", scriptBaseName())
		, CompilerPath    : FileExist("Ahk2Exe.exe") ? "Ahk2Exe.exe" : A_AhkPath "\..\Compiler\Ahk2Exe.exe"
		, EmbedAhkAds     : true
		, AdsName         : GetCmdParameterValue("--ads-name", "AutoHotkey.exe")
		, SkipDirPattern  : GetCmdParameterValue("--skip-dir-pattern") } ;Directory names in A_ScriptDir (non-recursive) to skip to. (regex)
		;===============================================================================================
;}

#NoEnv
#Warn UseUnsetLocal
#Warn UseUnsetGlobal
#UseHook

;Allow to launch this script for self-compilation while uncompiled version is running already.
;Second instance is prohibited by manual check in ScriptInfoUtils.checkForExistingInstance() function.
#SingleInstance OFF

#include <CommonUtils>
#include <AhkScriptController>
#include <TrayIconUtils>
#include <ErrMsg>
#include <ScriptInfoUtils>

SetTitleMatchMode 2 ;Match anywhere
DetectHiddenWindows ON
SetBatchLines -1

global cScriptResourceAliasPrefix := "StarterExeResourcePrefix_"

;@Ahk2Exe-IgnoreBegin
if (Config.CompileMe) {
	compilePackage()
	ExitApp
}

data := getScriptsForBundle()
global g_scriptNames := data.scripts
     , g_scriptsCmdLines := data.cmdLines
     , g_initialScriptNames := g_scriptNames.Clone() ;Immutable collection of script names
;@Ahk2Exe-IgnoreEnd

if (otherInstancePid := ScriptInfoUtils.checkForExistingInstance()) {
	MsgBox % "Already running (PID: " otherInstancePid ")"
	ExitApp
}
if (Config.Elevate) {
	CommonUtils.elevateThisScript()
}

/*@Ahk2Exe-Keep
	if (ConfigCompiled.Elevate) {
		CommonUtils.elevateThisScript()
	}
	global g_ahkRuntimeFile := extractExecutable()
	     , g_scriptNames := fetchScriptsList()
*/

OnExit("exitFunc")
OnMessage(WM_COMMAND := 0x111, "OnWM_COMMAND")

global g_scriptsPids := runScripts()
     , g_forceSuspend := false ;true if the scripts suspended by user manually. Must take precedence over automatic suspension methods if any
setupTray()

/*
 * Win+Shift+Escape — reload this script (preserving command line) and all of its managed scripts
*/
Hotkey(Config.ReloadAllShortcut, CommonUtils.getFuncObj("reloadScript"))

/* Win+Shift+` - Smart Reload Script matching %winTitle% (active window "A" by default)
 *
 *  This function can reload even those scripts not managed by Starter.
 *  If %winTitle% is not an instance of AutoHotkey.exe, the result of WinGetTitle(winTitle)
 *  matched against names of ALL AutoHotkey scripts running on the system. The matched
 *  script (if any) will be reloaded. This is very convenient to reload the script which you
 *  are currently editing (i.e. the name of that script can be found in the title of the text
 *  editor you are working in) for debugging purposes.
 *
 *  If matching script is managed by Starter.exe - reloads whole package.
 *  See comments below for more details.
*/
Hotkey("#+SC029", "smartReloadScript")

/*
 *     Win+Shift+S — Toggle suspend state of all managed scripts
 * Alt+Win+Shift+S — same as previous but for ALL running scripts found on the system
*/
Hotkey("#+s", "toggleSuspendScripts")
Hotkey("!#+s", "toggleSuspendScriptsAll")

/*
 * Place your custom code here if needed.
 * You can utilize g_scriptsPids global variable which contain all controlled scripts' PIDs
 * for use with "ahk_pid", for example. Alternatively (and preferably), place your code to the
 * optional injection file Starter_injection.ahk which included at the end of auto-execute section below.
*/
#include *i %A_LineFile%\..\Starter_injection.ahk

;
;--------------------------------------------End of auto-execute section------------------------------------------------
;

smartReloadScript(winTitle:="A") {
	;If this is one of the scripts managed by Starter.exe - just reload whole package, because
	;scripts running through named pipe have title like ".\\pipe\..." instead of human-readable path
	pid := WinGet("PID", winTitle)
	if (A_IsCompiled && HasVal(g_scriptsPids, pid)) {
			Reload
			return 0
	}

	if (scriptPath := CommonUtils.getAhkScriptFilePath(WinGet("ID", winTitle))) {
		if (pidIndex := HasVal(g_scriptsPids, pid)) { ;this script managed by Starter.ahk
			return reloadScript(pidIndex, scriptPath)
		}
		return CommonUtils.reloadScript(winTitle) ;this script is external, NOT managed by Starter.ahk
	}

	;If title of currently active window contains a (possibly part) file name of one of the
	;AHK scripts running on the system - reload matching script
	activeWinTitle := WinGetTitle(winTitle)
	for i, hWnd in WinGet("List", "ahk_class AutoHotkey") {
		fullPath := CommonUtils.getAhkScriptFilePath(hWnd)
		SplitPath(fullPath, scriptName)
		if (scriptName && InStr(activeWinTitle, scriptName)) {
			pid := WinGet("PID", "ahk_id" hWnd)
			if (pidIndex := HasVal(g_scriptsPids, pid)) {
				return reloadScript(pidIndex, fullPath)
			} else {
				return CommonUtils.reloadScript("ahk_pid" pid)
			}
		}
	}

	return 0
}

OnWM_COMMAND(wParam, lParam, msg, hWnd) {
	if (wParam = AhkScriptController.ID_FILE_SUSPEND || wParam = AhkScriptController.ID_TRAY_SUSPEND) {
		toggleSuspendScripts()
		return 0
	}
}

setSuspendScripts(willSuspend, childScriptsOnly := true, showOsdIndication := true) {
	; logDebug("childScriptsOnly:", childScriptsOnly)
	if (childScriptsOnly) {
		if (A_IsCompiled) {
			for each, pid in g_scriptsPids {
				AhkScriptController.setSuspend("ahk_pid" pid, willSuspend)
			}
		} else {
			if (Config.ChildScriptsMatchMode = "name") {
				for i, name in g_initialScriptNames {
					AhkScriptController.setSuspend(name " ahk_class AutoHotkey", willSuspend)
				}
			} else if (Config.ChildScriptsMatchMode = "pid") {
				for each, pid in g_scriptsPids {
					AhkScriptController.setSuspend("ahk_pid" pid, willSuspend)
				}
			}
		}
	} else {
		;Ignore suspension for current script to avoid unneeded recursion in OnMessage() handler. Current script will be
		;suspended explicitly with `Suspend` command further below
		prevValue := AhkScriptController.IgnoreCurrentScript
		AhkScriptController.IgnoreCurrentScript := true
		AhkScriptController.setSuspend("ahk_class AutoHotkey", willSuspend)
		AhkScriptController.IgnoreCurrentScript := prevValue
	}
	Suspend % willSuspend ? 1 : 0 ;Explicitly suspend itself

	if (showOsdIndication) {
		suspendEnabledText := childScriptsOnly ? " Ⓢ " : " Ⓢ  ALL "
		suspendDisabledText := childScriptsOnly ? " 🔆 " : " 🔆  ALL "
		CommonUtils.ShowSplashPictureWithText(,,, willSuspend ? suspendEnabledText : suspendDisabledText,,,100)
	}
}
toggleSuspendScripts(showOsdIndication := true) {
	Suspend Permit
	setSuspendScripts(g_forceSuspend := !g_forceSuspend, true, showOsdIndication)
}
toggleSuspendScriptsAll(showOsdIndication := true) {
	Suspend Permit
	setSuspendScripts(g_forceSuspend := !g_forceSuspend, false, showOsdIndication)
}

runPlanFileName() {
	return scriptBaseName() ".txt"
}

currentlyManagedScripts() {
	return g_scriptsPids
}

scriptsFromCommandLine() {
	scripts := []
	for i, param in A_Args {
		if (param ~= "\.ahk" && FileExist(param)) {
			scripts.Push(param)
		}
	}
	return scripts
}

;Returns all scripts from Config Section, then all scripts from Starter.txt in that order
getScriptsForBundle() {
	result := scriptsFromCommandLine()
	if (result.Length()) {
		return {scripts: result, cmdLines: []}
	}

	RegExMatch(FileRead(A_ScriptFullPath), "isO);\{ Config Section.+?;\}", matchObj)
	configSection := matchObj[0]
	cmdLines := []
	pos := 1
	while pos := RegExMatch(configSection
	                      , "imO);" (Config.CompileMe ? "" : "\s*") "@Ahk2Exe-AddResource \*RT_RCDATA (.+\.ahk)$"
	                      , matchObj
	                      , pos) {
		match := matchObj[1]
		pos += StrLen(match)
		if (!HasVal(result, match)) {
			result.Push(match)
			cmdLines.Push("")
		}
	}

	if (FileExist(runPlanFile := runPlanFileName())) {
		Loop Read, %runPlanFile%
		{
			if (A_LoopReadLine ~= "^\s*;") ;Skip comment lines starting with ";"
				continue

			fileWantCompile := A_LoopReadLine ~= "^~"
			if (Config.CompileMe && !fileWantCompile)
				continue

			path := fileWantCompile ? SubStr(A_LoopReadLine, 2) : A_LoopReadLine

			cmdLine := ""
			if (delimPos := InStr(path, "|")) {
				cmdLine := SubStr(path, delimPos + 1)
				path := SubStr(path, 1, delimPos - 1)
			}

			if (!(attr := FileExist(path)))
				continue

			if (isDirectory := InStr(attr, "D")) {
				Loop Files, %path%\*.ahk
				{
					cmdLines.Push("")
					Gosub RememberScriptPath
				}
			} else {
				cmdLines.Push(cmdLine)
				Gosub RememberScriptPath
			}
		}
	}
	; MsgBox % "Scripts to " (Config.CompileMe ? "compile: " : "launch: ") . ObjToString(result)

	if (result.Length() = 0) {
		showHelpDialog()
	}

	return {scripts: result, cmdLines: cmdLines}

	RememberScriptPath:
		scriptPath := isDirectory ? A_LoopFileLongPath : path
		if (HasVal(result, scriptPath))
			return
		if (Config.CompileMe && !fileWantCompile)
			return
		result.Push(scriptPath)
		return
}

runScript(path, cmdLine := "") {
	if (path) {
		absolutePath := GetAbsolutePath(path)
		scriptDir := ""
		SplitPath(absolutePath,, scriptDir)
		return Run(A_AhkPath " /CP65001 /restart " quote(absolutePath) . (cmdLine ? (" " cmdLine) : ""), scriptDir)
	}

	return 0
}

;Restart script \scriptPath and optionally update g_scriptsPids. Returns new PID of reloaded script
reloadScript(oldPidIndex, scriptPath) {
	newPid := runScript(scriptPath, g_scriptsCmdLines[oldPidIndex])
	if (oldPidIndex) {
		g_scriptsPids[oldPidIndex] := newPid
		TrayIconUtils_removeTrayIcons([newPid])
	}
	return newPid
}

showHelpDialog() {
	baseName := scriptBaseName()
	helpTxt := A_ScriptName " cannot find any scripts to " (Config.CompileMe ? "compile" : "launch")
		       . " in " runPlanFileName() " or auto-execute section or passed via drag & drop.`r`n`r`n"
	exampleTxtFile =
	(LTrim
		;Lines started with semicolon are comments and ignored, as well as empty lines
		;Each line in this file is a script path (or folder with scripts) to launch (can be absolute or relative to this file)
		;Put tilde (~) at the beginning of path to mark the script or folder for inclusion into compiled %baseName%.exe
		;Command line parameters for each script (but not a directory) can be specified after pipe character (|)

		;--------------------------------------Some Examples--------------------------------------------
		;                                      -------------
		;3rdparty\MyGoodScriptToLaunch.ahk
		;~ThisScriptWillBeCompiled.ahk
		;~C:\path\to\AnotherScriptWhichWillBeCompiled.ahk
		;script\with\CommandLineParameters.ahk|--first-cmd-parameter --second --config myconfig.ini
		;
		;Specify path to directory so all .ahk files in that directory will be launched
		;or compiled (if preceded with ~) into Starter.exe
		;
		;D:\Path\To\DirectoryWithScritpsToLaunch
		;~D:\Path\To\DirectoryWithScriptsToLaunchAndCompile
		;
		;-----------------------------------------------------------------------------------------------
		;Put path to your scripts below and run %A_ScriptName% when you are done.

	)
	MsgBox % helpTxt "(Press OK to start editing scripts list)"
	if (!FileExist(txtFile := scriptBaseName() ".txt")) {
		FileAppend(exampleTxtFile, txtFile)
	}
	Run % quote(txtFile)

	WinWait % txtFile,,3
	WinActivate % txtFile
	ExitApp
}

setupTrayTip() {
	tip := ""
	for i, name in g_scriptNames {
		tip .= " * " RegExReplace(cleanupScriptResourceAlias(name), "i)(.*[/\\])?(.+)\.ahk", "$2") "`n" ; Extract file's base name without extension
	}

	Menu Tray, Tip, % tip
}

cleanupScriptResourceAlias(resourceAlias) {
	return RegExReplace(resourceAlias, "i)" cScriptResourceAliasPrefix "\d+_") ; Case-insensitive, because Ahk2Exe makes resource aliases uppercase
}

exitFunc(exitReason, exitCode) {
	stopChildScripts()
/*@Ahk2Exe-Keep
		if (ConfigCompiled.AhkRuntimeInAds) {
			return ; No need to delete ADS file - it will be deleted automatically together with Starter.exe
		}

		FileDelete % g_ahkRuntimeFile
		if (ErrorLevel) {
			MsgBox % "Error deleting " quote(g_ahkRuntimeFile) ": " ErrMsg()
		}
*/
}

stopChildScripts() {
	errors := AhkScriptController.exitExternalScripts(g_scriptsPids, true)
	if (errors.Length()) {
		prev := LoggerConfiguration.WriteToFile
		LoggerConfiguration.WriteToFile := true
		logWarn("Errors occurred while exiting managed scripts: " ObjToString(errors))
		LoggerConfiguration.WriteToFile := prev
	}
	g_scriptsPids := []
}

;--------------------------Starter.ahk-only Functions--------------------------
;@Ahk2Exe-IgnoreBegin
runScripts() {
	pids := []
	for i, filePath in g_scriptNames {
			pids.Push(runScript(filePath, g_scriptsCmdLines[i]))
	}

	return pids
}

setupTray() {
	for i, name in g_scriptNames {
		Menu SubMenu_%name%, Add, View &Lines,       OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, View &Variables,   OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, View &Hotkeys,     OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, View &Key History, OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add
		Menu SubMenu_%name%, Add, &Open,             OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, &Reload,           OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, &Edit,             OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, &Exit,             OnScriptTrayCommandClicked

		Menu Tray, Add, &%name%, :SubMenu_%name%
	}

	Menu Tray, NoStandard
	Menu Tray, Add

	menuText := "&Compile " scriptBaseName() ".exe"
	Menu Tray, Add, %menuText%, OnScriptTrayCommandClicked

	showSummaryText := "Show Scripts Summary"
	Menu Tray, Add, %showSummaryText%, showScriptsSummary

	;Without explicit binding of empty parameter, the function will be called with standard parameters
	;for Menu's function (ItemName, ItemPos, MenuName) which is obviously a wrong winTitle for target script
	funcObj := CommonUtils.getFuncObj("reloadScript", "", "", "2")
	Menu Tray, Add, % "Reload (preserve command line) |" Config.ReloadAllShortcut "|", % funcObj

	menuText := "Reload as admin (preserve command line)"
	funcObj := CommonUtils.getFuncObj("elevateThisScript", false)
	Menu Tray, Add, % menuText, % funcObj
	if (A_IsAdmin) {
		Menu Tray, Disable, % menuText
	}

	menuText := "Edit " runPlanFileName()
	Menu Tray, Add, %menuText%, editRunPlanFile

	Menu Tray, Add

	Menu Tray, Standard

	Menu Tray, Default, %showSummaryText%

	if (Config.ShowTrayTip) {
		setupTrayTip()
	}
	CommonUtils.SetupTrayIcon()
	TrayIconUtils_ensureTrayIconsHidden(Func("currentlyManagedScripts"))
}

OnScriptTrayCommandClicked() {
	static Cmd_Open           := 65300
	     , Cmd_Reload         := AhkScriptController.ID_TRAY_RELOADSCRIPT
	     , Cmd_Edit           := 65401
	     , Cmd_Exit           := 65405
	     , Cmd_ViewLines      := 65406
	     , Cmd_ViewVariables  := 65407
	     , Cmd_ViewHotkeys    := 65408
	     , Cmd_ViewKeyHistory := 65409
	if (InStr(A_ThisMenuItem, "Compile")) {
		return Run(A_ScriptFullPath " --compile-package")
	}

	cmd := RegExReplace(A_ThisMenuItem, "[^\w#@$?\[\]]") ; strip invalid chars
	cmd := Cmd_%cmd%
	scriptNamePartial := RegExReplace(A_ThisMenu,"SubMenu_(.+$)","$1")

	if (cmd = Cmd_Exit) {
		fullPath := CommonUtils.getAhkScriptFilePath(WinGet("ID", scriptNamePartial))

		fileBaseName := ""
		SplitPath(fullPath,,,, fileBaseName)

		; tip := RegExReplace(A_IconTip, "s)\R? \* \Q" fileBaseName "\E\R?")
		tip := RegExReplace(A_IconTip, "\* " fileBaseName, "✘ " fileBaseName)
		Menu Tray, Tip, % tip

		for i, scriptPath in g_scriptNames {
			if InStr(fullPath, scriptPath) {
				g_scriptNames.Remove(i)
				g_scriptsPids.Remove(i)
				g_scriptsCmdLines.Remove(i)
				Menu Tray, Delete, %i%&
				break
			}
		}
	} else if (cmd = Cmd_Reload) {
		fullPath := CommonUtils.getAhkScriptFilePath(WinGet("ID", scriptNamePartial))
		for i, scriptPath in g_scriptNames
			if InStr(fullPath, scriptPath)
				return reloadScript(i, fullPath)
		return
	}

	AhkScriptController.sendCommand(scriptNamePartial, cmd)

	if (g_scriptNames.Length() = 0) {
		ExitApp
	}
}

showScriptsSummary() {
	rows := g_scriptNames.MaxIndex() + 5
	Gui Add, ListView, Grid +Resize r%rows% w600 Sort, Script|PID|Path|Command Line
	Loop, % g_scriptNames.MaxIndex() {
		SplitPath(g_scriptNames[A_Index], scriptName)
		pid := g_scriptsPids[A_Index]
		path := CommonUtils.getAhkScriptFilePath(WinGet("ID", "ahk_pid" pid))
		LV_Add(, scriptName, pid, path, g_scriptsCmdLines[A_Index])
	}
	LV_ModifyCol()
	LV_ModifyCol(3, "AutoHdr")

	title := "Controlled Scripts - " A_ScriptName
	Gui Show, Center, %title%
	return

	GuiEscape:
	GuiClose:
		Gui Destroy
		return
}

editRunPlanFile() {
	Run % runPlanFileName()
}

cleanTemporaryScripts() {
	for i, file in getScriptsForBundle().scripts {
			FileDelete % file . ".preprocessed"
	}

	FileDelete % A_ScriptFullPath ".augmented_with_addresource_directives"
}

compilePackage() {
	Menu Tray, Tip, % A_ScriptName " (Compiling...)"
	startTime := A_TickCount

	try {
	renamedDirectories := {} ;key -> original name; value -> new name
	if (Config.SkipDirPattern) {
		cRenameSuffix := "_"
		for i, v in StrSplit(Config.SkipDirPattern, "|")
			if (!FileExist(dirPath := A_ScriptDir "\" v))
				return MsgBox("Aborting due to impossibility to skip non-existent directory: " quote(dirPath))
		Loop Files, %A_ScriptDir%\*.*, D
		{
			if (!(A_LoopFileName ~= "i)" Config.SkipDirPattern))
				continue
			newDirName := A_LoopFileLongPath . cRenameSuffix
			FileMoveDir(A_LoopFileLongPath, newDirName, "R")
			;FileMove/FileMoveDir/FileDelete throw exception instead of setting ErrorLevel if finally{} block present.
			;But inside finally{} block itself they set ErrorLevel again instead of throwing…
			; if (ErrorLevel)
			; 	return MsgBox("Error renaming " quote(A_LoopFileLongPath) ": " ErrMsg()) ;executes finally{} block
			renamedDirectories[A_LoopFileLongPath] := newDirName
		}
	}

	compress := useCompression()
	OnExit("cleanTemporaryScripts") ;Ensure that intermediate scripts will be deleted even in case of exception in the code below
	inFile := preprocessScripts()
	outFile := A_ScriptDir "\" Config.ProductName (compress ? "c" : "") ".exe"

	;CMD cheat-sheet: Ahk2Exe.exe /in infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin AutoHotkeySC.bin] [/mpress 1 (true) or 0 (false)] [/cp codepage]
	RunWait % Config.CompilerPath " /in " quote(inFile) " /out " quote(outFile) . (compress ? " /compress 2" : ""),,UseErrorLevel
	cleanTemporaryScripts()

	; Terminates Ahk2Exe process and its child which waits on 'Ahk2Exe-Obey SelfCompilationCommandResult' directive
	; And delete orphaned temporary file(s)
	orphanedFile := ""
	for i, hWnd in WinGet("List", "ahk_exe Ahk2Exe.exe") {
		compilerPid := WinGet("PID", "ahk_id" hWnd)
		if (InStr(CommonUtils.getProcessCommandLine(compilerPid), A_ScriptName)) { ; If this is compiler which compiles us
			wmi := ComObjGet("winmgmts:")
			queryEnum := wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ParentProcessId=" compilerPid)._NewEnum()
			queryEnum[procCompilerChild] ;AutoHotkey.exe which waits in RunWait from Obey
			if (RegExMatch(procCompilerChild.CommandLine, "~Ahk2Exe.+\.tmp")) {
				orphanedFile := GetAbsolutePath(RegExReplace(procCompilerChild.CommandLine, ".+?(\Q" A_Temp "\E\\~Ahk2Exe.+\.tmp)", "$1"))
				Process Close, % compilerPid
				Process Close, % procCompilerChild.ProcessId
			}
		}
	}

	includedScripts := ""
	for i, scriptPath in getScriptsForBundle().scripts {
		includedScripts .= "    " scriptPath "`n"
	}
	MsgBox % Format("Compilation finished!`nProduct: {} v{}`n{} seconds elapsed`n`nIncluded scripts:`n{}`n`n{}`n{}"
		             , outFile
		             , Config.Version
		             , (A_TickCount - startTime) / 1000
		             , includedScripts
		             , "Press OK to finish"
		             , "(Hold Ctrl key to open product destination folder also)")

	if (GetKeyState("Ctrl", "P")) {
		WinExist(A_ScriptDir " ahk_exe explorer.exe") ? (WinRestore(), WinActivate(), CommonUtils.setExplorerSelection(WinExist(), [outFile]))
		                                              : Run("explorer.exe /select`, " outFile)
	}
	; logDebug("Deleting orphaned temporary: " quote(orphanedFile))
	if (FileExist(orphanedFile)) {
		FileDelete % orphanedFile
	}
	TrayIconUtils_removeOrphans()

	return outFile
	} catch e {
		MsgBox % "Exception: " ObjToString(e) "`nTraceBack: " ObjToString(Traceback())
	} finally {
		failedRenames := {}
		;Restore names for previously renamed directories
		for originalName, newName in renamedDirectories {
			FileMoveDir(newName, originalName, "R")
			if (ErrorLevel)
				failedRenames[originalName] := newName
		}
		if (failedRenames.Count()) {
			MsgBox % "Failed to restore original names: " ObjToString(failedRenames)
			ExitApp 1
		}
	}
}

preprocessScripts() {
	;-------------------------------------------------------------------------------------------------
	addResourceDirectives := ""
	for i, file in getScriptsForBundle().scripts {
		scriptIndex := A_Index
		Loop Files, %file%
		{
			scriptCopy := A_LoopFileLongPath . ".preprocessed"
			FileCopy(A_LoopFilePath, scriptCopy, 1)
			;Use undocumented Ahk2Exe-OutputPreproc directive, which accepts single parameter - path where to place preprocessed script
			FileAppend("`n;@Ahk2Exe-OutputPreproc " scriptCopy, scriptCopy)

			;Replace copy of original script with its preprocessed variant after compilation
			;/out to NUL because we interested only in preprocessed output for now
			exitCode := RunWait(Format("{:s} /in ""{:s}"" /out NUL", Config.CompilerPath, scriptCopy))
			if (exitCode != 0) {
				MsgBox % "Cannot preprocess script " quote(A_LoopFileLongPath) ".`n"
				       . "Error code: " exitCode
				ExitApp exitCode
			}

			;Add prefix to resource alias to allow further sorting and maintain correct launch order. See ResourceAliasSortFunctor()
			addResourceDirectives .= "`n;@Ahk2Exe-AddResource *RT_RCDATA " scriptCopy ", " cScriptResourceAliasPrefix . scriptIndex "_" A_LoopFilePath
		}
	}
	addResourceDirectives .= "`n"

	;-------------------------------------------------------------------------------------------------
	compiledConfigText := "/*@Ahk2Exe-Keep"
	               . "`nglobal ConfigCompiled :="
	               . "`n( LTrim Join"
	               . "`n{"

	if (Config.EmbedAhkAds) {
		compiledConfigText .= "`n AhkRuntimeInAds: true`n, AhkRuntimeAdsName: " quote(Config.AdsName) ","
	}
	compiledConfigText .= "`n Elevate: " (Config.Elevate ? "true" : "false") ","

	;Remove last comma if any
	if (SubStr(compiledConfigText, 0) = ",") {
		compiledConfigText := SubStr(compiledConfigText, 1, StrLen(compiledConfigText) - 1)
	}
	compiledConfigText .= "`n}`n)`n*/`n"
	;-------------------------------------------------------------------------------------------------

	;1. Create copy of this script
	;2. Add "global ConfigCompiled" object (which will be consulted in Starter.exe only) at the top
	;   of resulting script. The object may have no key/value pairs at all.
	;3. Add necessary Ahk2Exe directives for packaging
	outFileName := A_ScriptFullPath ".augmented_with_addresource_directives"

	thisScriptText := FileRead(A_ScriptFullPath)
	; Delete @Ahk2Exe-Obey directive from preprocessed script to prevent eternal spawning of Ahk2Exe processes
	thisScriptText := RegExReplace(thisScriptText, "m)^\s*;@Ahk2Exe-Obey SelfCompilationCommandResult.+$")

	FileAppend(compiledConfigText . addResourceDirectives . thisScriptText, outFileName, "UTF-8")

	return outFileName
}

useCompression() {
	compress := Config.UseCompression
	SplitPath(Config.CompilerPath,,compilerDirectory)
	if (Config.UseCompression && !FileExist(compilerDirectory "\upx.exe")) {
		if (FileExist("upx.exe")) {
			FileCopy("upx.exe", compilerDirectory "\upx.exe")
		} else {
			MsgBox % "upx.exe not found. Executable will not be compressed.`r`nPlace upx.exe near " A_ScriptName " to be able create compressed executable"
			compress := false
		}
	}

	return compress
}

;--------------------------End of Starter.ahk-only Functions--------------------------
;@Ahk2Exe-IgnoreEnd


;--------------------------Starter.exe-only Functions--------------------------
/*@Ahk2Exe-Keep
#WinActivateForce
DllRead( ByRef Var, Filename, Section, Key ) {    ; By SKAN | goo.gl/DjDxzW
	Local ResType, ResName, hMod, hRes, hData, pData, nBytes := 0
	  ResName := ( Key+0 ? Key : &Key ), ResType := ( Section+0 ? Section : &Section )

	  VarSetCapacity( Var,128 ), VarSetCapacity( Var,0 )
	  If hMod  := DllCall( "LoadLibraryEx", "Str",Filename, "Ptr",0, "UInt",0x2, "Ptr" )
	  If hRes  := DllCall( "FindResource", "Ptr",hMod, "Ptr",ResName, "Ptr",ResType, "Ptr" )
	  If hData := DllCall( "LoadResource", "Ptr",hMod, "Ptr",hRes, "Ptr" )
	  If pData := DllCall( "LockResource", "Ptr",hData, "Ptr" )
	  If nBytes := DllCall( "SizeofResource", "Ptr",hMod, "Ptr",hRes )
	     VarSetCapacity( Var,nBytes,1 )
	   , DllCall( "RtlMoveMemory", "Ptr",&Var, "Ptr",pData, "Ptr",nBytes )
	  DllCall( "FreeLibrary", "Ptr",hMod )
	Return nBytes
}

extractExecutable() {
	resultPath := A_Temp "\" UUIDCreate()
	if (ConfigCompiled.AhkRuntimeInAds) {
		;Only NTFS file system supports ADS. In other cases will fallback to temporary file
		if (DriveGet("FileSystem", SubStr(A_ScriptFullPath, 1, 3)) = "NTFS") {
			resultPath := A_ScriptFullPath ":" ConfigCompiled.AhkRuntimeAdsName
			if (FileExist(resultPath)) {
				return resultPath ;No need to write ADS again if it already there from previous launch
			}
		}
	}

	bytesCount := DllRead(var, A_ScriptFullPath, "RT_RCDATA", "RC_AHKRUNTIME")
	file := FileOpen(resultPath, "w")
	if (!IsObject(file)) {
		MsgBox % "Can't open " resultPath " for writing"
		ExitApp -3
	}
	file.RawWrite(var, bytesCount)
	return resultPath
}

runScripts() {
	pids := []
	for each, script in g_scriptNames {
		bytesCount := DllRead(data, A_ScriptFullPath, "RT_RCDATA", script)
		scriptText := StrGet(&data, bytesCount, "utf-8") ; convert bytes from utf-8 to native script's encoding
		pids.Push(ExecScript(g_ahkRuntimeFile, scriptText))
	}

	return pids
}

setupTray() {
	Menu Tray, NoStandard
	Menu Tray, Add, Exit, onExitTrayItemClicked

	if (Config.ShowTrayTip) {
		setupTrayTip()
	}

	;NOTE: do not call CommonUtils.SetupTrayIcon() here, because for the icon compiled script was set at compile time with @SetMainIcon directive

	TrayIconUtils_ensureTrayIconsHidden(Func("currentlyManagedScripts"))
}

onExitTrayItemClicked() {
	ExitApp
}

enumResourcesCallback(hModule, lpszType, lpszName, lParam) {
	resourceAlias := StrGet(lpszName)
	if (isAhkScriptResource := InStr(resourceAlias, ".ahk", false)) {
		Object(lParam).Push(resourceAlias)
	}
	; OutputDebug % StrGet(lpszType) " - " StrGet(lpszName) " - " lParam
	return true ; Return false to stop enumeration
}

;Extracts script names from the Starter.exe's resources
fetchScriptsList() {
	scriptNames := []
	if (!DllCall("EnumResourceNames", "Ptr",A_ScriptFullPath, "Str","RT_RCDATA", "Ptr",RegisterCallback("enumResourcesCallback", "F" ), "UInt",&scriptNames )) {
		MsgBox % "Error calling EnumResourceNames(): " ErrMsg()
		ExitApp -1
	}
	if (!scriptNames.Count()) {
		MsgBox % "No suitable resources found!"
		ExitApp -2
	}
	return sortArray(scriptNames, "F ResourceAliasSortFunctor")
}
ResourceAliasSortFunctor(a1, a2) {
	; Sorts in ascending numeric order. This method works only if the difference is never so large as to overflow a signed 64-bit integer.
	return (RegExReplace(a1, "i)^" cScriptResourceAliasPrefix "(\d+)_.+$", "$1"))
	     - (RegExReplace(a2, "i)^" cScriptResourceAliasPrefix "(\d+)_.+$", "$1"))
}

ExecScript(ahkPath, scriptText, scriptCommandLineParams := "", workingDir := "") {
	if !FileExist(ahkPath) {
		throw Exception("AutoHotkey runtime not found: " ahkPath)
	}

	pid := 0
	try {
		pipeName := "\\.\pipe\" A_TickCount
		pipeHandles := []
		Loop 3 {
			pipeHandles[A_Index] := DllCall("CreateNamedPipe"
				, "Str", pipeName
				, "UInt", 2, "UInt", 0
				, "UInt", 255, "UInt", 0
				, "UInt", 0, "UPtr", 0
				, "UPtr", 0, "UPtr")
		}

		if !FileExist(pipeName) {
			return 0
		}

		pid := Run(ahkPath " /CP65001 " pipeName " " scriptCommandLineParams, workingDir)
		DllCall("ConnectNamedPipe", "UPtr", pipeHandles[2], "UPtr", 0)
		DllCall("ConnectNamedPipe", "UPtr", pipeHandles[3], "UPtr", 0)
		FileOpen(pipeHandles[3], "h", "UTF-8").Write(scriptText)
	} finally {
		Loop 3 {
			DllCall("CloseHandle", "UPtr", pipeHandles[A_Index])
		}
	}

	return pid
}

UUIDCreate(mode:=1, format:="", ByRef UUID:="") {
	UuidCreate := "Rpcrt4\UuidCreate"
	if InStr("02", mode)
		UuidCreate .= mode? "Sequential" : "Nil"
	VarSetCapacity(UUID, 16, 0) ;// long(UInt) + 2*UShort + 8*UChar
	pString := ""
	if (DllCall(UuidCreate, "Ptr", &UUID) == 0)
	&& (DllCall("Rpcrt4\UuidToString", "Ptr", &UUID, "UInt*", pString) == 0)
	{
		string := StrGet(pString)
		DllCall("Rpcrt4\RpcStringFree", "UInt*", pString)
		if InStr(format, "U")
			DllCall("CharUpper", "Ptr", &string)
		return InStr(format, "{") ? "{" . string . "}" : string
	}
}
*/
;--------------------------End of Starter.exe-only Functions--------------------------
