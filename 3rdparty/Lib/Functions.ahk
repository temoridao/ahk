/*
	Title: Command Functions
		A wrapper set of functions for commands which have an output variable.

	License:
		- Version 1.41 <http://www.autohotkey.net/~polyethene/#functions>
		- Dedicated to the public domain (CC0 1.0) <http://creativecommons.org/publicdomain/zero/1.0/>
*/

Functions() {
	Return, true
}

ExitApp(exitCode := 0) {
	ExitApp exitCode
}
IfBetween(ByRef var, LowerBound, UpperBound) {
	If var between %LowerBound% and %UpperBound%
		Return, true
}
IfNotBetween(ByRef var, LowerBound, UpperBound) {
	If var not between %LowerBound% and %UpperBound%
		Return, true
}
IfIn(ByRef var, MatchList) {
	If var in %MatchList%
		Return, true
}
IfNotIn(ByRef var, MatchList) {
	If var not in %MatchList%
		Return, true
}
IfContains(ByRef var, MatchList) {
	If var contains %MatchList%
		Return, true
}
IfNotContains(ByRef var, MatchList) {
	If var not contains %MatchList%
		Return, true
}
IfIs(ByRef var, type) {
	If var is %type%
		Return, true
}
IfIsNot(ByRef var, type) {
	If var is not %type%
		Return, true
}

ControlGet(Cmd, Value = "", Control = "", WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	ControlGet, v, %Cmd%, %Value%, %Control%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
ControlGetFocus(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	ControlGetFocus, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
ControlGetText(Control = "", WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	ControlGetText, v, %Control%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
DriveGet(Cmd, Value = "") {
	DriveGet, v, %Cmd%, %Value%
	Return, v
}
DriveSpaceFree(Path) {
	DriveSpaceFree, v, %Path%
	Return, v
}
EnvGet(EnvVarName) {
	EnvGet, v, %EnvVarName%
	Return, v
}
FileAppend(Text := "", Filename := "", Encoding := "") {
	FileAppend, %Text%, %Filename%, %Encoding%
}
FileCopy(SourcePattern, DestPattern, Overwrite := false) {
	FileCopy, %SourcePattern%, %DestPattern%, %Overwrite%
}
FileCopyDir(Source, Dest, Overwrite:=false) {
	FileCopyDir, %Source%, %Dest%, %Overwrite%
}
FileMove(SourcePattern, DestPattern, Overwrite := false) {
	FileMove, %SourcePattern%, %DestPattern%, %Overwrite%
}
FileCreateDir(DirName) {
	FileCreateDir %DirName%
}
FileCreateShortcut(Target, LinkFile, WorkingDir:="", Args:="", Description:="", IconFile:="", ShortcutKey:="", IconNumber:="", RunState:="") {
	FileCreateShortcut %Target%, %LinkFile%, %WorkingDir%, %Args%, %Description%, %IconFile%, %ShortcutKey%, %IconNumber%, %RunState%
}
FileGetAttrib(Filename = "") {
	FileGetAttrib, v, %Filename%
	Return, v
}
FileGetShortcut(LinkFile, ByRef OutTarget = "", ByRef OutDir = "", ByRef OutArgs = "", ByRef OutDescription = "", ByRef OutIcon = "", ByRef OutIconNum = "", ByRef OutRunState = "") {
	FileGetShortcut, %LinkFile%, OutTarget, OutDir, OutArgs, OutDescription, OutIcon, OutIconNum, OutRunState
}
FileGetSize(Filename = "", Units = "") {
	FileGetSize, v, %Filename%, %Units%
	Return, v
}
FileGetTime(Filename = "", WhichTime = "") {
	FileGetTime, v, %Filename%, %WhichTime%
	Return, v
}
FileGetVersion(Filename = "") {
	FileGetVersion, v, %Filename%
	Return, v
}
FileRead(Filename) {
	FileRead, v, %Filename%
	Return, v
}
FileReadLine(Filename, LineNum) {
	v := ""
	FileReadLine, v, %Filename%, %LineNum%
	Return, v
}
FileRecycleEmpty(DriveLetter := "") {
	FileRecycleEmpty, %DriveLetter%
}
FileRemoveDir(DirName, Recurse := "") {
	FileRemoveDir %DirName%, %Recurse%
}
FileSelectFile(Options = "", RootDir = "", Prompt = "", Filter = "") {
	FileSelectFile, v, %Options%, %RootDir%, %Prompt%, %Filter%
	Return, v
}
FileSelectFolder(StartingFolder = "", Options = "", Prompt = "") {
	FileSelectFolder, v, %StartingFolder%, %Options%, %Prompt%
	Return, v
}
FormatTime(YYYYMMDDHH24MISS = "", Format = "") {
	FormatTime, v, %YYYYMMDDHH24MISS%, %Format%
	Return, v
}

GuiControlGet(Subcommand = "", ControlID = "", Param4 = "") {
	GuiControlGet, v, %Subcommand%, %ControlID%, %Param4%
	Return, v
}

/**
 * Check hotkey for existence in current script
 *
 * @param   hk  Hotkey with usual syntax expected by @c Hotkey builtin command
 *
 * @return @c false if @p hk does not exist or it has no variant for the current IfWin criteria;
 *         @c true otherwise
 */
HotkeyExist(hk) {
	Hotkey, %hk%,, UseErrorLevel
	if ErrorLevel in 5,6
		return false

	return true
}

Hotkey(KeyName, Label := "", Options := "", allowOverwriteLabel := false) {
	if (!allowOverwriteLabel && IfNotIn(Label, "On,Off,Toggle,AltTab") && HotkeyExist(KeyName)) {
		throw Exception("Attempt to overwrite hotkey: " KeyName)
	}
	Hotkey %KeyName%, %Label%, %Options%
}
HotkeyIf(functor := "") {
	static lastFunctor := ""
	prevFunctor := lastFunctor
	lastFunctor := functor

	if (functor) {
		if (!IsObject(functor)) {
			functor := Func(functor)
		}
		Hotkey If, % functor
	} else {
		Hotkey If
	}

	return prevFunctor
}

ImageSearch(ByRef OutputVarX, ByRef OutputVarY, X1, Y1, X2, Y2, ImageFile) {
	ImageSearch, OutputVarX, OutputVarY, %X1%, %Y1%, %X2%, %Y2%, %ImageFile%
}
IniRead(Filename, Section, Key, Default := "") {
	IniRead, v, %Filename%, %Section%, %Key%, %Default%
	Return, v
}
IniWrite(Value, Filename, Section, Key:="") {
	if (!FileExist(Filename)) {
		throw Exception("File doesn't exist: " Filename)
	}

	IniWrite, %Value%, %Filename%, %Section%, %Key%
}
IniDelete(Filename, Section, Key := "") {
	if (Key) {
		IniDelete, %Filename%, %Section%, %Key%
	} else {
		IniDelete, %Filename%, %Section%
	}
}
Input(Options = "", EndKeys = "", MatchList = "") {
	Input, v, %Options%, %EndKeys%, %MatchList%
	Return, v
}
InputBox(Title = "", Prompt = "", HIDE = "", Width = "", Height = "", X = "", Y = "", Font = "", Timeout = "", Default = "") {
	InputBox, v, %Title%, %Prompt%, %HIDE%, %Width%, %Height%, %X%, %Y%, , %Timeout%, %Default%
	Return, v
}
MouseGetPos(ByRef OutputVarX = "", ByRef OutputVarY = "", ByRef OutputVarWin = "", ByRef OutputVarControl = "", Mode = "") {
	MouseGetPos, OutputVarX, OutputVarY, OutputVarWin, OutputVarControl, %Mode%
}
MsgBox(text:="") {
	MsgBox, %text%
}
PixelGetColor(X, Y, RGB = "") {
	PixelGetColor, v, %X%, %Y%, %RGB%
	Return, v
}
PixelSearch(ByRef OutputVarX, ByRef OutputVarY, X1, Y1, X2, Y2, ColorID, Variation = "", Mode = "") {
	PixelSearch, OutputVarX, OutputVarY, %X1%, %Y1%, %X2%, %Y2%, %ColorID%, %Variation%, %Mode%
}
PostMessage(Msg, wParam:="", lParam:="", Control:="", WinTitle:="", WinText:="", ExcludeTitle:="", ExcludeText:="") {
	PostMessage, %Msg%, %wParam%, %lParam%, %Control%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
}
Progress(ProgressParam1 , SubText:="", MainText:="", WinTitle:="", FontName:="") {
	Progress, %ProgressParam1% , %SubText%, %MainText%, %WinTitle%, %FontName%
}
Random(Min = "", Max = "") {
	Random, v, %Min%, %Max%
	Return, v
}
RegRead(KeyName, ValueName:="") {
	RegRead, v, %KeyName%, %ValueName%
	Return, v
}
RegWrite(ValueType, KeyName, ValueName:="", Value:="") {
	RegWrite, %ValueType%, %KeyName%, %ValueName%, %Value%
	return !ErrorLevel
}
Reload() {
	Reload
}
Run(Target, WorkingDir = "", Mode = "") {
	Run, %Target%, %WorkingDir%, %Mode%, v
	Return, v
}
RunWait(Target, WorkingDir = "", Mode = "", ByRef OutputVarPID := "") {
	RunWait, %Target%, %WorkingDir%, %Mode%, OutputVarPID
	Return, ErrorLevel ;ErrorLevel contains process exit code
}
Send(Keys) {
	Send % Keys
}
SendRaw(Keys) {
	SendRaw % Keys
}
SendMessage(Msg, wParam:="", lParam:="", Control:="", WinTitle:="", WinText:="", ExcludeTitle:="", ExcludeText:="", Timeout:="") {
	SendMessage, %Msg%, %wParam%, %lParam%, %Control%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%, %Timeout%
	return ErrorLevel
}
SetTimer(Label := "", PeriodOnOff := "", Priority := "") { ; Known limitation: passing -0 as 'Period' do not honor minus, so you need to pass -1 or "-0" (as string, in double quotes)
	SetTimer, %Label%, %PeriodOnOff%, %Priority%
}
Sleep(DelayInMilliseconds) {
	Sleep DelayInMilliseconds
}
SoundBeep(Frequency:=523, Duration:=150) {
	SoundBeep Frequency, Duration
}
SoundGet(ComponentType = "", ControlType = "", DeviceNumber = "") {
	SoundGet, v, %ComponentType%, %ControlType%, %DeviceNumber%
	Return, v
}
SoundGetWaveVolume(DeviceNumber = "") {
	SoundGetWaveVolume, v, %DeviceNumber%
	Return, v
}
StatusBarGetText(Part = "", WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	StatusBarGetText, v, %Part%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
SplashTextOff() {
	SplashTextOff
}
SplitPath(ByRef InputVar, ByRef OutFileName = "", ByRef OutDir = "", ByRef OutExtension = "", ByRef OutNameNoExt = "", ByRef OutDrive = "") {
	SplitPath, InputVar, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
}
StringGetPos(ByRef InputVar, SearchText, Mode = "", Offset = "") {
	StringGetPos, v, InputVar, %SearchText%, %Mode%, %Offset%
	Return, v
}
StringLeft(ByRef InputVar, Count) {
	StringLeft, v, InputVar, %Count%
	Return, v
}
StringLen(ByRef InputVar) {
	StringLen, v, InputVar
	Return, v
}
StringLower(ByRef InputVar, T = "") {
	v := ""
	StringLower, v, InputVar, %T%
	Return, v
}
StringMid(ByRef InputVar, StartChar, Count , L = "") {
	StringMid, v, InputVar, %StartChar%, %Count%, %L%
	Return, v
}
StringReplace(ByRef InputVar, SearchText, ReplaceText = "", All = "") {
	StringReplace, v, InputVar, %SearchText%, %ReplaceText%, %All%
	Return, v
}
StringRight(ByRef InputVar, Count) {
	StringRight, v, InputVar, %Count%
	Return, v
}
StringTrimLeft(ByRef InputVar, Count) {
	StringTrimLeft, v, InputVar, %Count%
	Return, v
}
StringTrimRight(ByRef InputVar, Count) {
	StringTrimRight, v, InputVar, %Count%
	Return, v
}
StringUpper(ByRef InputVar, T = "") {
	StringUpper, v, InputVar, %T%
	Return, v
}
Suspend(Mode := "") {
	Suspend % Mode
}
SysGet(Subcommand, Param3 = "") {
	SysGet, v, %Subcommand%, %Param3%
	Return, v
}
ToolTip(Text:="", X:="", Y:="", WhichToolTip:="") {
	ToolTip, %Text%, %X%, %Y%, %WhichToolTip%
}
Transform(Cmd, Value1, Value2 = "") {
	Transform, v, %Cmd%, %Value1%, %Value2%
	Return, v
}
WinGet(Cmd = "", WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	if (Cmd = "List") {
		WinGet, allHwnd, List, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
		resultArray := []
		Loop % allHwnd {
			resultArray.Push(allHwnd%A_Index%)
		}
		return resultArray
	}

	WinGet, v, %Cmd%, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
WinGetActiveTitle() {
	WinGetActiveTitle, v
	Return, v
}
WinGetClass(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinGetClass, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
WinGetText(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinGetText, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
WinGetTitle(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinGetTitle, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}

WinActivate(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinActivate, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
}

WinMenuSelectItem(WinTitle, WinText, Menu, SubMenu1:="", SubMenu2:="", SubMenu3:="", SubMenu4:="", SubMenu5:="", SubMenu6:="", ExcludeTitle:="", ExcludeText:="") {
	WinMenuSelectItem, %WinTitle%, %WinText%, %Menu%, %SubMenu1%, %SubMenu2%, %SubMenu3%, %SubMenu4%, %SubMenu5%, %SubMenu6%, %ExcludeTitle%, %ExcludeText%
	Return !ErrorLevel
}

WinMove(WinTitle, WinText, X, Y, Width:="", Height:="", ExcludeTitle:="", ExcludeText:="")  {
	WinMove, %WinTitle%, %WinText%, %X%, %Y%, %Width%, %Height%, %ExcludeTitle%, %ExcludeText%
}

WinRestore(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinRestore, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%

	;Alternative variant:
	; PostMessage, 0x112, 0xF120,,, %winTitle%, %WinText% ; 0x112 = WM_SYSCOMMAND, 0xF120 = SC_RESTORE
}

WinKill(WinTitle := "", WinText := "", SecondsToWait := "", ExcludeTitle := "", ExcludeText := "") {
	WinKill, %WinTitle%, %WinText%, %SecondsToWait%, %ExcludeTitle%, %ExcludeText%
}

WinMaximize(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinMaximize, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
}

WinMinimize(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinMinimize, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
}

WinClose(WinTitle = "", WinText = "", SecondsToWait = "", ExcludeTitle = "", ExcludeText = "") {
	WinClose, %WinTitle%, %WinText%, %SecondsToWait%, %ExcludeTitle%, %ExcludeText%
}

WinMinimizeAll() {
	WinMinimizeAll
}

KeyWait(KeyName, Options:="") {
	KeyWait, %KeyName%, %Option%
}
