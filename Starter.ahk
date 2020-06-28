/**
 * Description:
 *    Smart launcher for your scripts with optional ability to compile (combine) all of them into
 *    a single portable Starter.exe executable by one click.
 * Requirements:
 *    Latest version of AutoHotkey (tested on v1.1.32)
 * Installation:
 *    git clone --recursive https://github.com/temoridao/ahk
 *        or download latest snapshot here: https://github.com/temoridao/ahk/releases
 *
 *    Launch Starter.ahk and it will create Starter.txt, prompting you for the list of scripts.
 *    After you have done, save txt file and launch Starter.ahk again. Now you have all your scripts
 *    running under control of Starter.ahk.
 *    To compile your scripts into single portable .exe file, select Tray Menu > Compile Starter.exe
 *
 *    See README for the list of features and other details: https://github.com/temoridao/ahk/blob/master/README.md
 * Links:
 *    GitHub     : https://github.com/temoridao/ahk
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
SetWorkingDir %A_ScriptDir%

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
	; @Ahk2Exe-SetMainIcon Starter.exe.ico
	; @Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%" "11.UPX." "1.UPX!.", 2
	;-------------------------------------------------------------------------------------------------

	global Config := { Version : "1.0.0"
		;@Ahk2Exe-SetVersion %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%

		, Elevate         : CommonUtils.HasValue(A_Args, "--elevate")
		, ShowTrayTip     : CommonUtils.HasValue(A_Args, "--enable-tray-tip") || !A_IsCompiled

		;========================Options for compilation process========================================
		, CompileMe       : CommonUtils.HasValue(A_Args, "--compile-package")
		, UseCompression  : CommonUtils.HasValue(A_Args, "--compress-package")
		, ProductName     : scriptBaseName()
		, CompilerPath    : FileExist("Ahk2Exe.exe") ? "Ahk2Exe.exe"
		                                             : A_AppData "\" A_ScriptName "\Ahk2Exe.exe" }
;}

#NoEnv
#Warn UseUnsetLocal
#Warn UseUnsetGlobal

;Allow to launch this script for self-compilation while uncompiled version is running already.
;Second instance is prohibited by manual check in checkForExistingInstance() function.
#SingleInstance OFF

SetTitleMatchMode 2 ;Match anywhere
DetectHiddenWindows ON
SetBatchLines -1
#include <CommonUtils>
#include <AhkScriptController>
#include <TrayIconUtils>
#include <ErrMsg>

;@Ahk2Exe-IgnoreBegin
checkCompilator()
if (Config.CompileMe && !A_IsCompiled) {
	compilePackage()
	ExitApp
}

global g_scriptNames := getScriptsForBundle()
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
global g_scriptsPids := runScripts(), g_trayTip := "", g_toggleSuspend := false
setupTray()

;Place your custom code here if needed
;You can utilize g_scriptsPids variable which contain all controlled scripts' PIDs
;for use with "ahk_pid", for example. Alternatively, place your code inside injection file as explained below


;
;-----------------------------------End of auto-execute section-------------------------------------
;

;You can optionally create files with path and names listed below and place there any code you want
;or add custom hotkeys.
;=====================================Optional Injections===========================================
#include *i %A_LineFile%\..\Shared\Starter_injection_common.ahk     ;<==For both Starter.{ahk,exe}
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Shared\Starter_injection_compiled.ahk   ;<==For Starter.exe only
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Shared\Starter_injection_uncompiled.ahk ;<==For Starter.ahk only
;@Ahk2Exe-IgnoreEnd

;=====================================Optional Injections===========================================
#include *i %A_LineFile%\..\Internal\Starter_injection_common.ahk
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Starter_injection_compiled.ahk
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Internal\Starter_injection_uncompiled.ahk
;@Ahk2Exe-IgnoreEnd
;===================================================================================================

;Win+Shift+Escape — reload this script with all of its managed scripts at once
#+Escape::Reload

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
		if (A_IsCompiled && CommonUtils.HasValue(g_scriptsPids, pid)) {
				Reload
				return 0
		}

		;If this is some other 3rdparty AHK script (NOT managed by Starter), or managed by Starter.ahk,
		;reload it by passing /restart command line parameter to AutoHotkey.exe
		if (scriptPath := CommonUtils.getAhkScriptFilePath(WinGet("ID", winTitle))) {
			return reloadScript(CommonUtils.HasValue(g_scriptsPids, pid), scriptPath)
		}

		;If title of currently active window contains a (possibly part) file name of one of the
		;AHK scripts running on the system - reload matching script
		activeWinTitle := WinGetTitle(winTitle)
		for i, hWnd in WinGet("List", "ahk_class AutoHotkey") {
			fullPath := CommonUtils.getAhkScriptFilePath(hWnd)
			SplitPath(fullPath, scriptName)
			if (scriptName && InStr(activeWinTitle, scriptName)) {
				return reloadScript(CommonUtils.HasValue(g_scriptsPids, WinGet("PID", "ahk_id" hWnd)), fullPath)
			}
		}

		return 0
	}

/* Win+Alt+Escape — Temporary Suspend
 *
 *  Suspends all hotkeys in managed scripts unconditionally for %interval% ms.
 *  It may be convenient in some situations to completely suspend all hotkeys in all managed scripts.
*/
#!Escape::
	temporarySuspend(interval := 3000) {
		setSuspend(true)
		; Disable all "Suspend Permit" hotkeys
		HotKey("#+s", "Off")
		HotKey("!#+s", "Off")
		CommonUtils.ShowSplashPictureWithText(,,, " ⏸️ ",,,100, 500)

		Sleep interval

		; Reenable all "Suspend Permit" hotkeys
		HotKey("#+s", "On")
		HotKey("!#+s", "On")
		setSuspend(false)
		CommonUtils.ShowSplashPictureWithText(,,, " ▶️ ",,,100, 500)
	}

/*
 * Win+Shift+S — Toggle Suspend state of all managed scripts until next activation of this hotkey
 * Win+Shift+Alt+S — same as previous but for ALL running scripts found on the system
*/
 #+s::
!#+s::
	toggleSuspendScripts() {
		Suspend Permit
		suspendAllScriptsOnTheSystem := InStr(A_ThisHotkey, "!")
		setSuspend(g_toggleSuspend := !g_toggleSuspend, !suspendAllScriptsOnTheSystem)

		suspendEnabledText := suspendAllScriptsOnTheSystem ? " Ⓢ  ALL " : " Ⓢ "
		suspendDisabledText := suspendAllScriptsOnTheSystem ? " 🔆  ALL " : " 🔆 "
		CommonUtils.ShowSplashPictureWithText(,,, g_toggleSuspend ? suspendEnabledText : suspendDisabledText,,,100)
	}

setSuspend(willSuspend, childScriptsOnly := true) {
	if (childScriptsOnly) {
		for each, pid in g_scriptsPids {
			AhkScriptController.setSuspend("ahk_pid" pid, willSuspend)
		}
		Suspend % willSuspend ? 1 : 0 ;Suspend Starter itself except hotkeys marked with "Suspend Permit" (currently only single hotkey permitted - the one which toggles suspension)
	} else {
			AhkScriptController.setSuspend("ahk_class AutoHotkey", willSuspend)
	}
}

checkForExistingInstance() {
	if (WinGet("List", A_ScriptName " ahk_class AutoHotkey").Length() > 1) {
		MsgBox % "Already exists"
		ExitApp
	}
}

scriptBaseName() {
	return SubStr(A_ScriptName, 1, InStr(A_ScriptName, ".ahk") -1)
}

getScriptsForBundle() {
	RegExMatch(FileRead(A_ScriptFullPath), "isO);\{ Config Section.+?;\}", matchObj)
	configSection := matchObj[0]
	scripts := {}
	pos := 1
	while pos := RegExMatch(configSection
	                      , "imO);" (Config.CompileMe ? "" : "\s*") "@Ahk2Exe-AddResource \*RT_RCDATA (.+\.ahk)$"
	                      , matchObj
	                      , pos) {
		match := matchObj[1]
		pos += StrLen(match)
		scripts[match] := ""
	}

	if (FileExist(runPlanFile := scriptBaseName() ".txt")) {
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

	result := []
	for script in scripts {
		result.Push(script)
	}

	; MsgBox % "Scripts to " (Config.CompileMe ? "compile: " : "launch: ") . CommonUtils.ObjToString(result)

	if (result.Length() = 0) {
		showHelpDialog()
	}

	return result

	RememberScriptPath:
		if (Config.CompileMe) {
			if (fileWantCompile) {
				scripts[isDirectory ? A_LoopFileLongPath : path] := ""
			}
		} else {
			scripts[isDirectory ? A_LoopFileLongPath : path] := ""
		}
		return
} putTextToClipboard(text) {
	Clipboard := text
}

runScript(path) {
	if (path) {
		absolutePath := CommonUtils.makeAbsolutePath(path)
		scriptDir := ""
		SplitPath(absolutePath,, scriptDir)
		return Run(A_AhkPath " /restart """ absolutePath """", scriptDir)
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
	helpTxt := A_ScriptName " cannot find any scripts to " (Config.CompileMe ? "compile" : "launch") ".`r`nYou must specify which scripts to launch/compile in the " scriptBaseName() ".txt like this:`r`n`r`n"
	exampleTxtFile =
	(LTrim
		;Each line here is a script path to launch (can be absolute or relative to this file)
		;Each line where first character is tilde (~) is also a script path to launch BUT it will additionally be compiled into Starter.exe (Tray Menu > Compile Starter.exe)
		;Lines started with semicolon are comments and ignored as well as empty lines
		;Some examples:
		3rdparty\GoodScript.ahk
		~Automation.ahk
		~C:\path\to\AnotherGoodScript.ahk

		;Specify path to directory and ALL .ahk files in that directory will be launched or compiled (if preceded with ~) into single Starter.exe file
		D:\Path\To\MyScriptsFolder


	)
	helpConfigSection := "=============================`r`nAlternatively you can specify which script to launch/compile directly at the top of " A_ScriptName " Config Section like this:`r`n`r`n"
	exampleConfigSection =
	(LTrim
		;Config Section at the top of Starter.ahk:
		;@Ahk2Exe-AddResource *RT_RCDATA MyCoolScript1.ahk
		;@Ahk2Exe-AddResource *RT_RCDATA work\Automation.ahk
		;@Ahk2Exe-AddResource *RT_RCDATA D:\storage\GoodScript.ahk


	)
	HotkeyIf(Func("WinActive").Bind("ahk_pid" DllCall("GetCurrentProcessId"), "", "", "")),
	HotKey("^c", Func("putTextToClipboard").Bind(exampleTxtFile exampleConfigSection))
	HotkeyIf()

	MsgBox % helpTxt exampleTxtFile helpConfigSection exampleConfigSection "(Press Ctrl+C to copy examples above)"
	if (!FileExist(txtFile := scriptBaseName() ".txt")) {
		FileAppend(exampleTxtFile, txtFile)
	}
	Run % """" txtFile """"

	WinWait % txtFile,,3
	WinActivate % txtFile
	ExitApp
}

setupTrayTip() {
	for i, name in g_scriptNames {
		g_trayTip .= " * " RegExReplace(name, "i)(.*\\)?(.+)\.ahk", "$2") "`n" ; Extract file's base name without extension
	}

	Menu Tray, Tip, % g_trayTip
}

exitFunc(exitReason, exitCode) {
	for i, pid in g_scriptsPids {
		AhkScriptController.sendCommand("ahk_pid" pid, AhkScriptController.ID_FILE_EXIT)
	}

	for i, pid in g_scriptsPids {
		winTitle := "ahk_pid" pid " ahk_class AutoHotkey"
		WinWaitClose % winTitle,,1
		if (ErrorLevel) {
			MsgBox % "Wait for process exiting timed out (PID: " pid ")"
		}
	}

/*@Ahk2Exe-Keep
	FileDelete % g_ahkRuntimeFile
	if (ErrorLevel) {
		MsgBox % "Error while deleting " g_ahkRuntimeFile ": " ErrMsg()
	}
*/
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

	compileItemText := "&Compile " scriptBaseName() ".exe"
	Menu Tray, Add, %compileItemText%, OnScriptTrayCommandClicked

	showSummaryText := "Show Scripts Summary"
	Menu Tray, Add, %showSummaryText%, showScriptsSummary

	Menu Tray, Add

	Menu Tray, Standard

	Menu Tray, Default, %showSummaryText%

	if (Config.ShowTrayTip) {
		setupTrayTip()
	}
	CommonUtils.SetupTrayIcon()
	TrayIconUtils_ensureTrayIconsHidden(g_scriptsPids)
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

		; g_trayTip := RegExReplace(g_trayTip, "s)\R? \* \Q" fileBaseName "\E\R?")
		g_trayTip := RegExReplace(g_trayTip, "\* " fileBaseName, "✘ " fileBaseName)
		Menu Tray, Tip, % g_trayTip

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

cleanTemporaryScripts() {
	for i, file in getScriptsForBundle() {
			FileDelete % file . ".preprocessed"
	}

	FileDelete % A_ScriptFullPath ".augmented_with_addresource_directives"
}

compilePackage() {
	Menu Tray, Tip, % A_ScriptName " (Compiling...)"
	startTime := A_TickCount
	if (!FileExist(Config.CompilerPath)) {
		bootstrapCompiler()
	}

	compress := useCompression()
	OnExit("cleanTemporaryScripts") ;Ensure that intermediate scripts will be deleted even in case of exception in the code below
	inFile := preprocessScripts()
	outFile := A_ScriptDir "\" Config.ProductName (compress ? "c" : "") ".exe"

	;CMD cheat-sheet: Ahk2Exe.exe /in infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin AutoHotkeySC.bin] [/mpress 1 (true) or 0 (false)] [/cp codepage]
	RunWait % Config.CompilerPath " /in " inFile " /out " outFile . (compress ? " /compress 2" : ""),,UseErrorLevel
	cleanTemporaryScripts()

	MsgBox % Format("Compilation finished!`n`nProduct: {1} v{2}`n`n{3} seconds elapsed"
		             , outFile
		             , Config.Version
		             , (A_TickCount - startTime) / 1000)
	WinExist(A_ScriptDir " ahk_exe explorer.exe") ? (WinRestore(), WinActivate(), CommonUtils.setExplorerSelection(WinExist(), [outFile]))
	                                              : Run("explorer.exe /select`, " outFile)
	return outFile
}

bootstrapCompiler() {
	SplitPath(Config.CompilerPath,,compilerDirectory)
	FileCreateDir % compilerDirectory
	compilerSource := A_ScriptDir "\3rdparty\Ahk2Exe\Ahk2Exe.ahk"
	RunWait(compilerSource " /in " compilerSource " /out " Config.CompilerPath, "3rdparty\Ahk2Exe")
}

preprocessScripts() {
	addResourceDirectives := ""
	for i, file in getScriptsForBundle() {
		Loop %file%, 1
		{
			scriptCopy := A_LoopFileLongPath . ".preprocessed"
			FileCopy(A_LoopFilePath, scriptCopy, 1)
			;Use undocumented Ahk2Exe-OutputPreproc directive, which accepts single parameter - path where to place preprocessed script
			FileAppend("`r`n;@Ahk2Exe-OutputPreproc " scriptCopy, scriptCopy)

			;Replace copy of original script with its preprocessed variant after compilation
			;/out to NUL because we interested only in preprocessed output for now
			RunWait % Format("{:s} /in {:s} /out NUL", Config.CompilerPath, scriptCopy)
			addResourceDirectives .= "`r`n;@Ahk2Exe-AddResource *RT_RCDATA " scriptCopy ", " A_LoopFilePath
		}
	}

	;Create copy of this script, adding necessary directives for packaging
	outFile := A_ScriptFullPath ".augmented_with_addresource_directives"
	FileCopy(A_ScriptFullPath, outFile, true)
	FileAppend(addResourceDirectives, outFile)
	return outFile
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

checkCompilator() {
	if (A_IsCompiled) {
		text =
		(LTrim
			This script must be compiled with latest Ahk2Exe compiler which supports @Ahk2Exe directives from
			https://github.com/AutoHotkey/Ahk2Exe.git

			Afterwards choose Tray Menu > Compile Starter.exe or pass --compile-package option to this script and it will compile itself

			Follow carefully "How to Use" instructions at `%URL to README.md`%
		)
		MsgBox % text
		Run https://github.com/temoridao/ahk/blob/master/README.md#starterahk
		ExitApp -1
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

	TrayIconUtils_ensureTrayIconsHidden(g_scriptsPids)
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
