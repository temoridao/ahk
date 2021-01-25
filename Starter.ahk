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

	global Config := { Version : "2.7.1"
		;@Ahk2Exe-SetVersion %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%

		, Elevate          : HasVal(A_Args, "--elevate")
		, ShowTrayTip      : HasVal(A_Args, "--enable-tray-tip") || !A_IsCompiled
		, ExposeComApi     : HasVal(A_Args, "--expose-com-api")
		, ChildScriptsMatchMode : GetCmdParameterValue("--child-scripts-match-mode", "name") ; Possible values: "name", "pid"

		;========================Options for compilation process========================================
		, CompileMe       : HasVal(A_Args, "--compile-package")
		, UseCompression  : HasVal(A_Args, "--compress-package")
		, ProductName     : GetCmdParameterValue("--product-name", ScriptInfoUtils.scriptBaseName())
		, CompilerPath    : FileExist("Ahk2Exe.exe") ? "Ahk2Exe.exe" : A_AhkPath "\..\Compiler\Ahk2Exe.exe"
		, EmbedAhkAds     : true
		, AdsName         : GetCmdParameterValue("--ads-name", "AutoHotkey.exe") }
		;===============================================================================================
;}

#NoEnv
#Warn UseUnsetLocal
#Warn UseUnsetGlobal

;Allow to launch this script for self-compilation while uncompiled version is running already.
;Second instance is prohibited by manual check in checkForExistingInstance() function.
#SingleInstance OFF

#include <CommonUtils>
#include <AhkScriptController>
#include <TrayIconUtils>
#include <ErrMsg>
#include <ScriptInfoUtils>

#include %A_LineFile%\..\3rdparty\Lib\ObjRegisterActive.ahk

SetTitleMatchMode 2 ;Match anywhere
DetectHiddenWindows ON
SetBatchLines -1

global cScriptResourceAliasPrefix := "StarterExeResourcePrefix_"
     , cReloadMark := "Reloading..."

;@Ahk2Exe-IgnoreBegin
if (Config.CompileMe) {
	compilePackage()
	ExitApp
}

global g_scriptNames := getScriptsForBundle()
     , g_initialScriptNames := g_scriptNames.Clone() ;Immutable collection of script names
;@Ahk2Exe-IgnoreEnd

checkForExistingInstance()
if (Config.Elevate) {
	CommonUtils.elevateThisScript()
}

/*@Ahk2Exe-Keep
	global g_ahkRuntimeFile := A_Temp "\" UUIDCreate(), g_scriptNames := []
	compiledOnlyAutoExecuteSection()
*/

OnExit("exitFunc")
global g_scriptsPids := runScripts()
     , g_forceSuspend := false ;true if the scripts suspended by user manually. Must take precedence over automatic suspension methods if any
setupTray()

if (Config.ExposeComApi) {
	cGuid := "{665dca48-2d24-47fd-af8a-c868ce906785}"
	ObjRegisterActive(StarterActiveObject, cGuid)
	logDebug("Exposed COM active object with GUID " cGuid ": " CommonUtils.ObjToString(StarterActiveObject))
	;Exposed COM object can be used from another application/script. Working AutoHotkey script example:
	/*
	global scriptsManagerActiveObj := ComObjActive("{665dca48-2d24-47fd-af8a-c868ce906785}") ;Starter.ahk API
	if (!scriptsManagerActiveObj) {
		MsgBox % "Starter.ahk not running or without --expose-com-api switch or " A_ScriptName " has insufficient access rights"
		ExitApp 1
	}
	F1::scriptsManagerActiveObj.Suspended := true ;press F1 to suspend all managed scripts
	F2::scriptsManagerActiveObj.Suspended := false ;press F2 to unsuspend all managed scripts
	*/
}

;Place your custom code here if needed
;You can utilize g_scriptsPids variable which contain all controlled scripts' PIDs
;for use with "ahk_pid", for example. Alternatively, place your code inside injection file as explained below


;
;-----------------------------------End of auto-execute section-------------------------------------
;

;You can optionally create files with path and names listed below and place there any code you want
;or add custom hotkeys.
;=============================Shared set of optional injections=====================================
#include *i %A_LineFile%\..\Shared\Starter_injection_common.ahk     ;<==For both Starter.{ahk,exe}
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Shared\Starter_injection_compiled.ahk   ;<==For Starter.exe only
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Shared\Starter_injection_uncompiled.ahk ;<==For Starter.ahk only
;@Ahk2Exe-IgnoreEnd

;=============================Internal set of optional injections===================================
#include *i %A_LineFile%\..\Internal\Starter_injection_common.ahk
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Starter_injection_compiled.ahk
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Internal\Starter_injection_uncompiled.ahk
;@Ahk2Exe-IgnoreEnd
;===================================================================================================

;Win+Shift+Escape — reload this script (preserving command line) and all of its managed scripts
#+Escape::CommonUtils.reloadThisScriptPreserveCmdLine()

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
#+SC029::smartReloadScript() ? SoundBeep(1000, 70) : ""
	smartReloadScript(winTitle:="A") {
		;If this is one of the scripts managed by Starter.exe - just reload whole package, because
		;scripts running through named pipe have title like ".\\pipe\..." instead of human-readable path
		pid := WinGet("PID", winTitle)
		if (A_IsCompiled && HasVal(g_scriptsPids, pid)) {
				Reload
				return 0
		}

		;If this is some other 3rdparty AHK script (NOT managed by Starter), or managed by Starter.ahk,
		;reload it by passing /restart command line parameter to AutoHotkey.exe
		if (scriptPath := CommonUtils.getAhkScriptFilePath(WinGet("ID", winTitle))) {
			return reloadScript(HasVal(g_scriptsPids, pid), scriptPath)
		}

		;If title of currently active window contains a (possibly part) file name of one of the
		;AHK scripts running on the system - reload matching script
		activeWinTitle := WinGetTitle(winTitle)
		for i, hWnd in WinGet("List", "ahk_class AutoHotkey") {
			fullPath := CommonUtils.getAhkScriptFilePath(hWnd)
			SplitPath(fullPath, scriptName)
			if (scriptName && InStr(activeWinTitle, scriptName)) {
				return reloadScript(HasVal(g_scriptsPids, WinGet("PID", "ahk_id" hWnd)), fullPath)
			}
		}

		return 0
	}

/*
 * Win+Shift+S — Toggle Suspend state of all managed scripts until next activation of this hotkey. Press twice to launch windows os builit-in screen snip tool
 * Win+Shift+Alt+S — same as previous but for ALL running scripts found on the system
*/
#+s::
	Suspend Permit
	HandleMultiPressHotkey({1: "toggleSuspendScripts"
	                      , 2: FSend(A_ThisHotkey)}
	                      , 100)
	return
!#+s::
	Suspend Permit
	toggleSuspendScripts(true)
	return

toggleSuspendScripts(suspendAllScriptsOnTheSystem := false) {
	Suspend Permit
	setSuspend(g_forceSuspend := !g_forceSuspend, !suspendAllScriptsOnTheSystem)

	suspendEnabledText := suspendAllScriptsOnTheSystem ? " Ⓢ  ALL " : " Ⓢ "
	suspendDisabledText := suspendAllScriptsOnTheSystem ? " 🔆  ALL " : " 🔆 "
	CommonUtils.ShowSplashPictureWithText(,,, g_forceSuspend ? suspendEnabledText : suspendDisabledText,,,100)
}

setSuspend(willSuspend, childScriptsOnly := true) {
	if (childScriptsOnly) {
		if (Config.ChildScriptsMatchMode = "name") {
			for i, name in g_initialScriptNames {
				AhkScriptController.setSuspend(name " ahk_class AutoHotkey", willSuspend)
			}
		} else if (Config.ChildScriptsMatchMode = "pid") {
			for each, pid in g_scriptsPids {
				AhkScriptController.setSuspend("ahk_pid" pid, willSuspend)
			}
		}
	} else {
		AhkScriptController.setSuspend("ahk_class AutoHotkey", willSuspend)
	}

	Suspend % willSuspend ? 1 : 0 ;Suspend Starter itself except hotkeys marked with "Suspend Permit" (currently only single hotkey permitted - the one which toggles suspension)
}

checkForExistingInstance() {
	myPid := DllCall("GetCurrentProcessId")
	for i, hWnd in WinGet("List", A_ScriptName " ahk_class AutoHotkey") {
		if (WinGet("PID", "ahk_id" hWnd) = myPid) {
			continue
		}

		title := WinGetTitle("ahk_id" hWnd)
		if (title && !InStr(title, cReloadMark)) {
			MsgBox % "Already running"
			ExitApp
		}
	}
}

runPlanFileName() {
	return ScriptInfoUtils.scriptBaseName() ".txt"
}

currentlyManagedScripts() {
	return g_scriptsPids
}

;Returns all scripts from Config Section, then all scripts from Starter.txt in that order
getScriptsForBundle() {
	RegExMatch(FileRead(A_ScriptFullPath), "isO);\{ Config Section.+?;\}", matchObj)
	configSection := matchObj[0]
	result := []
	pos := 1
	while pos := RegExMatch(configSection
	                      , "imO);" (Config.CompileMe ? "" : "\s*") "@Ahk2Exe-AddResource \*RT_RCDATA (.+\.ahk)$"
	                      , matchObj
	                      , pos) {
		match := matchObj[1]
		pos += StrLen(match)
		if (!HasVal(result, match)) {
			result.Push(match)
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

			if (!(attr := FileExist(path)))
				continue

			if (isDirectory := InStr(attr, "D")) {
				Loop Files, %path%\*.ahk
				{
					Gosub RememberScriptPath
				}
			} else {
				Gosub RememberScriptPath
			}
		}
	}
	; MsgBox % "Scripts to " (Config.CompileMe ? "compile: " : "launch: ") . CommonUtils.ObjToString(result)

	if (result.Length() = 0) {
		showHelpDialog()
	}

	return result

	RememberScriptPath:
		scriptPath := isDirectory ? A_LoopFileLongPath : path
		if (HasVal(result, scriptPath))
			return
		if (Config.CompileMe && !fileWantCompile)
			return
		result.Push(scriptPath)
		return
}

runScript(path) {
	if (path) {
		absolutePath := CommonUtils.makeAbsolutePath(path)
		scriptDir := ""
		SplitPath(absolutePath,, scriptDir)
		return Run(A_AhkPath " /restart " quote(absolutePath), scriptDir)
	}

	return 0
}

;Restart script \scriptPath and optionally update g_scriptsPids. Returns new PID of reloaded script
reloadScript(oldPidIndex, scriptPath) {
	newPid := runScript(scriptPath)
	if (oldPidIndex) {
		g_scriptsPids[oldPidIndex] := newPid
		TrayIconUtils_removeTrayIcons([newPid])
	}
	return newPid
}

showHelpDialog() {
	baseName := ScriptInfoUtils.scriptBaseName()
	helpTxt := A_ScriptName " cannot find any scripts to " (Config.CompileMe ? "compile" : "launch") ".`r`n"
	         . "The scripts to launch/compile should be specified in " baseName ".txt.`r`n`r`n"
	exampleTxtFile =
	(LTrim
		;Lines started with semicolon are comments and ignored, as well as empty lines
		;Each line in this file is a script path (or folder with scripts) to launch (can be absolute or relative to this file)
		;Put tilde (~) at the beginning of path to mark the script or folder for inclusion into compiled %baseName%.exe

		;--------------------------------------Some Examples--------------------------------------------
		;                                      -------------
		;3rdparty\MyGoodScriptToLaunch.ahk
		;~ThisScriptWillBeCompiled.ahk
		;~C:\path\to\AnotherScriptWhichWillBeCompiled.ahk
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
	if (!FileExist(txtFile := ScriptInfoUtils.scriptBaseName() ".txt")) {
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
	if (Config.ExposeComApi) {
		ObjRegisterActive(StarterActiveObject, "")
	}

/*@Ahk2Exe-Keep
		if (ConfigCompiled.AhkRuntimeInAds) {
			return ; No need to delete ADS file - it will be deleted automatically together with Starter.exe
		}

		FileDelete % g_ahkRuntimeFile
		if (ErrorLevel) {
			MsgBox % "Error while deleting " g_ahkRuntimeFile ": " ErrMsg()
		}
*/
}

stopChildScripts() {
	if (!AhkScriptController.exitExternalScripts(g_scriptsPids, true)) {
		MsgBox % ErrorLevel " error(s) occurred while exiting managed scripts"
	}
	g_scriptsPids := []
}

;--------------------------Starter.ahk-only Functions--------------------------
;@Ahk2Exe-IgnoreBegin
runScripts() {
	pids := []
	for i, filePath in g_scriptNames {
			pids.Push(runScript(filePath))
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
		Menu SubMenu_%name%, Add, &Edit,             OnScriptTrayCommandClicked
		Menu SubMenu_%name%, Add, &Exit,             OnScriptTrayCommandClicked

		Menu Tray, Add, &%name%, :SubMenu_%name%
	}

	Menu Tray, NoStandard
	Menu Tray, Add

	compileItemText := "&Compile " ScriptInfoUtils.scriptBaseName() ".exe"
	Menu Tray, Add, %compileItemText%, OnScriptTrayCommandClicked

	showSummaryText := "Show Scripts Summary"
	Menu Tray, Add, %showSummaryText%, showScriptsSummary

	reloadAll := CommonUtils.getFuncObj("reloadThisScriptPreserveCmdLine")
	Menu Tray, Add, Reload (preserve command line) [#+Escape], %reloadAll%

	editTxt := "Edit " runPlanFileName()
	Menu Tray, Add, %editTxt%, editRunPlanFile

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
				Menu Tray, Delete, %i%&
				break
			}
		}
	}

	AhkScriptController.sendCommand(scriptNamePartial, cmd)

	if (g_scriptNames.Length() = 0) {
		ExitApp
	}
}

showScriptsSummary() {
	rows := g_scriptNames.MaxIndex() + 5
	Gui Add, ListView, Grid +Resize r%rows% w500 Sort, Script|PID|Path
	Loop, % g_scriptNames.MaxIndex() {
		SplitPath(g_scriptNames[A_Index], scriptName)
		pid := g_scriptsPids[A_Index]
		path := CommonUtils.getAhkScriptFilePath(WinGet("ID", "ahk_pid" pid))
		LV_Add(, scriptName, pid, path)
	}
	LV_ModifyCol()
	LV_ModifyCol(3, "AutoHdr")

	title := "Controlled Scripts - " A_ScriptName
	Gui Show, Center, %title%
	return

	GuiEscape:
		Gui Destroy
		return
}

editRunPlanFile() {
	Run % runPlanFileName()
}

cleanTemporaryScripts() {
	for i, file in getScriptsForBundle() {
			FileDelete % file . ".preprocessed"
	}

	FileDelete % A_ScriptFullPath ".augmented_with_addresource_directives"
}

compilePackage() {
	Menu Tray, Tip, % A_ScriptName " (Compiling...)"
	startTime := A_TickCount

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
				orphanedFile := CommonUtils.makeAbsolutePath(RegExReplace(procCompilerChild.CommandLine, ".+?(\Q" A_Temp "\E\\~Ahk2Exe.+\.tmp)", "$1"))
				Process Close, % compilerPid
				Process Close, % procCompilerChild.ProcessId
			}
		}
	}

	MsgBox % Format("Compilation finished!`n`nProduct: {1} v{2}`n`n{3} seconds elapsed"
		             , outFile
		             , Config.Version
		             , (A_TickCount - startTime) / 1000)
	WinExist(A_ScriptDir " ahk_exe explorer.exe") ? (WinRestore(), WinActivate(), CommonUtils.setExplorerSelection(WinExist(), [outFile]))
	                                              : Run("explorer.exe /select`, " outFile)

	logDebug("Deleting orphanded temporary: " orphanedFile)
	FileDelete % orphanedFile
	if (ErrorLevel) {
		logWarn("Error deleting file: " ErrMsg())
	}
	TrayIconUtils_removeOrphans()

	return outFile
}

preprocessScripts() {
	;-------------------------------------------------------------------------------------------------
	addResourceDirectives := ""
	for i, file in getScriptsForBundle() {
		scriptIndex := A_Index
		Loop %file%, 1
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

class StarterActiveObject {
	Suspended[]
	{
		get {
			return g_forceSuspend
		}
		set {
			if (g_forceSuspend != value) {
				g_forceSuspend := value
				setSuspend(value)
			}

			return g_forceSuspend
		}
	}
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

compiledOnlyAutoExecuteSection() {
	if (!A_IsCompiled) {
		MsgBox % "This script should be used only in compiled form (because it will search for scripts in its .exe resources). Exit now."
		ExitApp -1
	}

	extractExecutable()
	fetchScriptsList()
}

extractExecutable() {
	if (ConfigCompiled.AhkRuntimeInAds) {
		fs := DriveGet("FileSystem", SubStr(A_ScriptFullPath, 1, 3))
		if (fs = "NTFS") {
			g_ahkRuntimeFile := A_ScriptFullPath ":" ConfigCompiled.AhkRuntimeAdsName
		} else {
			OutputDebug % "Only NTFS file system supports ADS. Current fs: " fs
			            . ". Will fallback to temporary file: " g_ahkRuntimeFile
		}
	}

	if (FileExist(g_ahkRuntimeFile)) {
		return ; No need to write ADS if it already there
	}

	bytesCount := DllRead(var, A_ScriptFullPath, "RT_RCDATA", "RC_AHKRUNTIME")
	file := FileOpen(g_ahkRuntimeFile, "w")
	if !IsObject(file) {
		MsgBox % "Can't open " g_ahkRuntimeFile " for writing"
		ExitApp -3
	}
	file.RawWrite(var, bytesCount)
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
		g_scriptNames.Push(resourceAlias)
	}
	; OutputDebug % StrGet(lpszType) " - " StrGet(lpszName) " - " lParam
	return true ; Return false to stop enumeration
}

;Extracts script names from the Starter.exe's resources
fetchScriptsList() {
	if (!DllCall("EnumResourceNames", "Ptr",A_ScriptFullPath, "Str","RT_RCDATA", "Ptr",RegisterCallback("enumResourcesCallback", "F" ), "UInt",123 )) {
		MsgBox % "Error calling EnumResourceNames(): " ErrMsg()
		ExitApp -1
	}
	if (!g_scriptNames.Count()) {
		MsgBox % "No suitable resources found!"
		ExitApp -2
	}
	g_scriptNames := sortArray(g_scriptNames, "F ResourceAliasSortFunctor")
	; MsgBox % CommonUtils.ObjToString(g_scriptNames)
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
