; Insert Parameter List for AHK Commands/Functions with Auto-Complete
; by boiler
;
; Thanks to Helgef and jeeswg for their effort on the list of commands, functions, and directives,
; which I have adapted and used in this script.
;
; Usage:
;	- CapsLock: Start command/function entry, searching by from start of command/function name
;	- Shift + CapsLock: Alternative commandfunction entry mode which will find anywhere in command/function name
;	  (to use different hotkeys, just find/replace "CapsLock" and "+CapsLock" with your own
;	- Enter to select command/function (can use up/down arrows to navigate command/function list)
;	- Parameter list will be displayed -- multiple versions if there are alternatives
;	- Enter to select parameter list (can use up/down arrows to navigate alternate parameter lists)
;	- Escape to return to normal editing
;
; It should work with any editor that allows pasting and returns caret positions (Sublime Text does not).
; Some may require special treatment as was done for SciTE4AHK (activates the edit control in case the Find box is open).
; It was tested with the editors below.  If you don't see yours, add it and try it out.
SetTitleMatchMode, RegEx
;GroupAdd, Editors, ahk_exe notepad++.exe
;GroupAdd, Editors, ahk_exe ahk_exe SciTE.exe
;GroupAdd, Editors, AutoGUI ahk_class AutoHotkeyGUI
;GroupAdd, Editors, AHK Studio ahk_class AutoHotkeyGUI
GroupAdd, Editors, i)\.ahk ahk_exe qtcreator\.exe
GroupAdd, Editors, ahk_exe sublime_text.exe

CoordMode, Caret, Screen

Commands := []
Parameters := {}

gosub, CommandListing
Loop, Parse, CommandText, `n
{
	Loop, Parse, A_LoopField, `;
	{
		if (A_Index = 1)
		{
			if (A_LoopField != LastCommand)
			{
				CurrentCommand := A_LoopField
				Commands.Push(CurrentCommand)
				Parameters[CurrentCommand] := []
				LastCommand := CurrentCommand
			}
		}
		if (A_Index = 2)
			Parameters[CurrentCommand].Push(A_LoopField)
	}
}

Gui, -Caption +AlwaysOnTop +ToolWindow
Gui, Font, s10, Consolas
Gui, Margin, 0, 0
Gui, Add, Edit, w170 h20 vCommandSearch gCommandTypingEvent
Gui, Add, ListBox, h0 w170 vCommandChoice -HScroll
Gui, Show, Hide AutoSize, Get Parameters

Gui, Params:-Caption +AlwaysOnTop +ToolWindow +Delimiter~ ; because pipe appears in parameter lists
Gui, Params:Font, s10, Consolas
Gui, Params:Margin, 0, 0
Gui, Params:Add, ListBox, h0 w300 vParamDisplay -HScroll
Gui, Params:Show, Hide AutoSize, Parameters List

return
; ***  End of auto-execute section  ***

CommandTypingEvent:
	GuiControlGet, CommandEntry,, CommandSearch
	PipedCommandList := "|"
	ListCount := 0
	if CommandEntry
	{
		if Anywhere
		{
			Loop, % Commands.MaxIndex()
			{
				if (InStr(Commands[A_Index], CommandEntry)) ; matches anywhere
				{
					PipedCommandList .= Commands[A_Index] "|"
					ListCount++
				}
			}
		}
		else
		{
			Loop, % Commands.MaxIndex()
			{
				if (SubStr(Commands[A_Index], 1, StrLen(CommandEntry)) = CommandEntry) ; matches at start
				{
					PipedCommandList .= Commands[A_Index] "|"
					ListCount++
				}
			}
		}
	}

	GuiControl, Move, CommandChoice, % "h" 4 + 15 * (ListCount > 4 ? 5 : ListCount)
	GuiControl, % ListCount ? "Show" : "Hide", CommandChoice
	StringTrimRight, PipedCommandList, PipedCommandList, 1 ; remove last pipe
	GuiControl,, CommandChoice, %PipedCommandList%
	HighlightedCommand := 1
	GuiControl, Choose, CommandChoice, 1
	Gui, Show, AutoSize
return

#IfWinActive, ahk_group Editors

!Space::
;+CapsLock::
	;Anywhere := InStr(A_ThisHotkey, "+")
	Anywhere := true
	GuiControl,, CommandSearch ; clear entry
	GuiControl,, CommandChoice, | ; clear list
	GuiControl, Hide, CommandChoice
	centerX := A_ScreenWidth / 2
	centerY := A_ScreenHeight / 2
	Gui, Show, x%centerX% y%centerY% AutoSize
return

#IfWinActive, Get Parameters ahk_exe AutoHotkey.exe
Esc::
	Gui, Cancel
return

Up::
^p::
	if (HighlightedCommand > 1)
	{
		HighlightedCommand--
		GuiControl, Choose, CommandChoice, %HighlightedCommand%
		Gui, Show, AutoSize
	}
return

Down::
^n::
	if (HighlightedCommand < ListCount)
	{
		HighlightedCommand++
		GuiControl, Choose, CommandChoice, %HighlightedCommand%
		Gui, Show, AutoSize
	}
return

Enter::
Tab::
	GuiControlGet, SelectedCommand,, CommandChoice
	if (!SelectedCommand || !CommandEntry || !ListCount)
	{
		Gui, Cancel
		return
	}
	Gui, Cancel
	WinWaitActive, ahk_group Editors
	CurrentCaretX := A_CaretX
	Paste(SelectedCommand)
	;Loop
		;Sleep, 50
	;until A_CaretX > CurrentCaretX ; wait until paste is complete so gui is in correct place
	Sleep, 200
	CurrentCaretX := A_ScreenWidth / 2
	CurrentCaretY := A_ScreenHeight / 2
	PipedParamList := "~"
	MaxChars := 0
	Loop, % Parameters[SelectedCommand].MaxIndex()
	{
		PipedParamList .= Parameters[SelectedCommand][A_Index] "~"
		if (StrLen(Parameters[SelectedCommand][A_Index]) > MaxChars)
			MaxChars := StrLen(Parameters[SelectedCommand][A_Index])
	}
	GuiControl, Params:Move, ParamDisplay, % "w" (8 + MaxChars * 7) "h" (4 + 15 * Parameters[SelectedCommand].MaxIndex())
	StringTrimRight, PipedParamList, PipedParamList, 1 ; remove last pipe
	GuiControl, Params:, ParamDisplay, %PipedParamList%
	HighlightedParam := 1
	GuiControl, Params:Choose, ParamDisplay, 1
	Gui, Params:Show, x%CurrentCaretX% y%CurrentCaretY% AutoSize
return

#IfWinActive, Parameters List ahk_exe AutoHotkey.exe
Esc::
	Gui, Params:Cancel
return

Up::
^p::
	if (HighlightedParam > 1)
	{
		HighlightedParam--
		GuiControl, Params:Choose, ParamDisplay, %HighlightedParam%
		Gui, Params:Show, AutoSize
	}
return

Down::
^n::
	if (HighlightedParam < Parameters[SelectedCommand].MaxIndex())
	{
		HighlightedParam++
		GuiControl, Params:Choose, ParamDisplay, %HighlightedParam%
		Gui, Params:Show, AutoSize
	}
return

Enter::
Tab::
	Gui, Params:Cancel
	WinWaitActive, ahk_group Editors
	Paste(Parameters[SelectedCommand][HighlightedParam])
return

Paste(text)
{
	IfWinActive, ahk_exe ahk_exe SciTE.exe
		ControlFocus, Scintilla1, A ; so that find/replace pane doesn't get focus
	savedClip := ClipboardAll
	Clipboard := text
	Send, ^v
	Clipboard := savedClip
}

CommandListing:
CommandText =
(Join`n %
#If;[, Expression]
#IfWinActive;[, WinTitle, WinText]
#IfWinExist;[, WinTitle, WinText]
#IfWinNotActive;[, WinTitle, WinText]
#IfWinNotExist;[, WinTitle, WinText]
#InputLevel;[, Level]
#SingleInstance;[force|ignore|off]
#UseHook;[On|Off]
#Warn;[, WarningType, WarningMode]
Abs;(Number)
ACos;(Number)
Asc;(String)
ASin;(Number)
ATan;(Number)
AutoTrim;, On|Off
Bind;(Parameters)
BlockInput;, Mode
Break;[, LoopLabel]
Ceil;(Number)
Chr;(Number)
ClipWait;[, SecondsToWait, 1]
Clone;()
Close;()
ComObjActive;(CLSID)
ComObjArray;(VarType, Count1 [, Count2, ... Count8])
ComObjConnect;(ComObject [, Prefix])
ComObjCreate;(CLSID [, IID])
ComObject;(VarType, Value [, Flags])
ComObjEnwrap;(DispPtr)
ComObjError;([Enable])
ComObjFlags;(ComObject [, NewFlags, Mask])
ComObjGet;(Name)
ComObjMissing;()
ComObjQuery;(ComObject, [SID,] IID)
ComObjType;(ComObject)
ComObjType;(ComObject, "Name")
ComObjType;(ComObject, "IID")
ComObjUnwrap;(ComObject)
ComObjValue;(ComObject)
Continue;[, LoopLabel]
Control;, Cmd [, Value, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlClick;[, Control-or-Pos, WinTitle, WinText, WhichButton, ClickCount, Options, ExcludeTitle, ExcludeText]
ControlFocus;[, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlGet;, OutputVar, Cmd [, Value, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlGetFocus;, OutputVar [, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlGetPos;[, X, Y, Width, Height, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlGetText;, OutputVar [, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlMove;, Control, X, Y, Width, Height [, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlSend;[, Control, Keys, WinTitle, WinText, ExcludeTitle, ExcludeText]
ControlSetText;[, Control, NewText, WinTitle, WinText, ExcludeTitle, ExcludeText]
CoordMode;, ToolTip|Pixel|Mouse|Caret|Menu [, Screen|Window|Client]
Cos;(Number)
Critical;[, Off]
CtrlEvent;(CtrlHwnd, GuiEvent, EventInfo, ErrorLevel:="")
DetectHiddenText;, On|Off
DetectHiddenWindows;, On|Off
DllCall;("[DllFile\]Function" [, Type1, Arg1, Type2, Arg2, "Cdecl ReturnType"])
Drive;, Sub-command [, Drive , Value]
DriveGet;, OutputVar, Cmd [, Value]
DriveSpaceFree;, OutputVar, Path
EnvAdd;, Var, Value [, TimeUnits]
EnvDiv;, Var, Value
EnvGet;, OutputVar, EnvVarName
EnvMult;, Var, Value
EnvSet;, EnvVar, Value
EnvSub;, Var, Value [, TimeUnits]
Exit;[, ExitCode]
ExitApp;[, ExitCode]
ExitFunc;(ExitReason, ExitCode)
Exp;(N)
FileAppend;[, Text, Filename, Encoding]
FileCopy;, SourcePattern, DestPattern [, Flag]
FileCopyDir;, Source, Dest [, Flag]
FileCreateDir;, DirName
FileCreateShortcut;, Target, LinkFile [, WorkingDir, Args, Description, IconFile, ShortcutKey, IconNumber, RunState]
FileDelete;, FilePattern
FileEncoding;[, Encoding]
FileGetAttrib;, OutputVar [, Filename]
FileGetShortcut;, LinkFile [, OutTarget, OutDir, OutArgs, OutDescription, OutIcon, OutIconNum, OutRunState]
FileGetSize;, OutputVar [, Filename, Units]
FileGetTime;, OutputVar [, Filename, WhichTime]
FileGetVersion;, OutputVar [, Filename]
FileInstall;, Source, Dest [, Flag]
FileMove;, SourcePattern, DestPattern [, Flag]
FileMoveDir;, Source, Dest [, Flag]
FileOpen;(Filename, Flags [, Encoding])
FileRead;, OutputVar, Filename
FileRead;, OutputVar, *Pnnn Filename
FileReadLine;, OutputVar, Filename, LineNum
FileRecycle;, FilePattern
FileRecycleEmpty;[, DriveLetter]
FileRemoveDir;, DirName [, Recurse?]
FileSelectFile;, OutputVar [, Options, RootDir\Filename, Prompt, Filter]
FileSelectFolder;, OutputVar [, StartingFolder, Options, Prompt]
FileSetAttrib;, Attributes [, FilePattern, OperateOnFolders?, Recurse?]
FileSetTime;[, YYYYMMDDHH24MISS, FilePattern, WhichTime, OperateOnFolders?, Recurse?]
Floor;(Number)
For; Key [, Value] in Expression
FormatTime;, OutputVar [, YYYYMMDDHH24MISS, Format]
Func;(FunctionName)
GetAddress;(Key)
GetCapacity;()
GetCapacity;(Key)
GetKeyName;(Key)
GetKeySC;(Key)
GetKeyState;, OutputVar, KeyName [, Mode]
GetKeyState;("KeyName" [, "Mode"])
GetKeyVK;(Key)
Gosub;, Label
Goto;, Label
GroupActivate;, GroupName [, R]
GroupAdd;, GroupName [, WinTitle, WinText, Label, ExcludeTitle, ExcludeText]
GroupClose;, GroupName [, A|R]
GroupDeactivate;, GroupName [, R]
Gui;, sub-command [, Param2, Param3, Param4]
GuiContextMenu;(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y)
GuiControl;, Sub-command, ControlID [, Param3]
GuiControlGet;, OutputVar [, Sub-command, ControlID, Param4]
GuiSize;(GuiHwnd, EventInfo, Width, Height)
HasKey;(Key)
Hotkey;, KeyName [, Label, Options]
Hotkey;, IfWinActive/Exist [, WinTitle, WinText]
Hotkey;, If [, Expression]
Hotkey;, If, % FunctionObject
if; (expression)
IfEqual;, var, value
IfExist;, FilePattern
IfGreater;, var, value
IfGreaterOrEqual;, var, value
IfInString;, var, SearchString
IfLess;, var, value
IfLessOrEqual;, var, value
IfMsgBox;, ButtonName
IfNotEqual;, var, value
IfNotExist;, FilePattern
IfNotInString;, var, SearchString
IfWinActive;[, WinTitle, WinText,  ExcludeTitle, ExcludeText]
IfWinExist;[, WinTitle, WinText,  ExcludeTitle, ExcludeText]
IfWinNotActive;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
IfWinNotExist;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
ImageSearch;, OutputVarX, OutputVarY, X1, Y1, X2, Y2, ImageFile
IniDelete;, Filename, Section [, Key]
IniRead;, OutputVar, Filename, Section, Key [, Default]
IniRead;, OutputVarSection, Filename, Section
IniRead;, OutputVarSectionNames, Filename
IniWrite;, Value, Filename, Section, Key
IniWrite;, Pairs, Filename, Section
Input;[, OutputVar, Options, EndKeys, MatchList]
InputBox;, OutputVar [, Title, Prompt, HIDE, Width, Height, X, Y, Font, Timeout, Default]
Insert;(StringOrObjectKey, Value)
InsertAt;(Pos, Value1 [, Value2, ... ValueN])
InStr;(Haystack, Needle [, CaseSensitive = false, StartingPos = 1, Occurrence = 1])
IsByRef;(UnquotedVarName)
IsByRef;(ParamIndex)
IsFunc;(FunctionName)
IsLabel;(LabelName)
IsObject;(ObjectValue)
IsOptional;(ParamIndex)
KeyWait;, KeyName [, Options]
Length;()
ListLines;[, On|Off]
Ln;(Number)
LoadPicture;(Filename [, Options, ByRef ImageType])
Log;(Number)
Loop;[, Count]
Loop;, Files, FilePattern [, Mode]
Loop;, FilePattern [, IncludeFolders?, Recurse?]
Loop;, Parse, InputVar [, Delimiters, OmitChars]
Loop;, Read, InputFile [, OutputFile]
Loop;, Reg, RootKey[\Key, Mode]
Loop;, RootKey [, Key, IncludeSubkeys?, Recurse?]
LTrim;(String, OmitChars = " `t")
MaxIndex;()
Menu;, MenuName, Cmd [, P3, P4, P5]
MenuGetHandle;(MenuName)
MenuGetName;(Handle)
MinIndex;()
Mod;(Dividend, Divisor)
MouseClick;[, WhichButton , X, Y, ClickCount, Speed, D|U, R]
MouseClickDrag;, WhichButton, X1, Y1, X2, Y2 [, Speed, R]
MouseGetPos;, [OutputVarX, OutputVarY, OutputVarWin, OutputVarControl, 1|2|3]
MouseMove;, X, Y [, Speed, R]
MsgBox;, Text
MsgBox;[, Options, Title, Text, Timeout]
Next;(OutputVar1 [, OutputVar2, ...])
NumGet;(VarOrAddress [, Offset = 0][, Type = "UPtr"])
NumPut;(Number, VarOrAddress [, Offset = 0][, Type = "UPtr"])
ObjAddRef;(Ptr)
ObjBindMethod;(Obj, Method, Params)
ObjRawSet;(Object, Key, Value)
ObjRelease;(Ptr)
OnClipboardChange;(Func [, AddRemove])
OnExit;[, Label]
OnMessage;(MsgNumber [, Function, MaxThreads])
OnMessage;(MsgNumber, "FunctionName")
OnMessage;(MsgNumber, "")
OnMessage;(MsgNumber)
OnMessage;(MsgNumber, FuncObj)
OnMessage;(MsgNumber, FuncObj, 1)
OnMessage;(MsgNumber, FuncObj, -1)
OnMessage;(MsgNumber, FuncObj, 0)
_NewEnum;()
Ord;(String)
OutputDebug;, Text
Pause;[, On|Off|Toggle, OperateOnUnderlyingThread?]
PixelGetColor;, OutputVar, X, Y [, Alt|Slow|RGB]
PixelSearch;, OutputVarX, OutputVarY, X1, Y1, X2, Y2, ColorID [, Variation, Fast|RGB]
Pop;()
PostMessage;, Msg [, wParam, lParam, Control, WinTitle, WinText, ExcludeTitle, ExcludeText]
Process;, Cmd [, PID-or-Name, Param3]
Progress;, Off
Progress;, ProgressParam1 [, SubText, MainText, WinTitle, FontName]
Push;([ Value, Value2, ..., ValueN ])
Random;, OutputVar [, Min, Max]
Random;, , NewSeed
RawRead;(VarOrAddress, Bytes)
RawWrite;(VarOrAddress, Bytes)
ReadLine;()
ReadNumType;()
RegDelete;, RootKey, SubKey [, ValueName]
RegExMatch;(Haystack, NeedleRegEx [, UnquotedOutputVar = "", StartingPosition = 1])
RegExReplace;(Haystack, NeedleRegEx [, Replacement = "", OutputVarCount = "", Limit = -1, StartingPosition = 1])
RegisterCallback;("FunctionName" [, Options = "", ParamCount = FormalCount, EventInfo = Address])
RegRead;, OutputVar, RootKey, SubKey [, ValueName]
RegWrite;, ValueType, RootKey, SubKey [, ValueName, Value]
Remove;(FirstKey, LastKey)
RemoveAt;(Pos [, Length])
Return;[, Expression]
Round;(Number [, N])
RTrim;(String, OmitChars = " `t")
Run;, Target [, WorkingDir, Max|Min|Hide|UseErrorLevel, OutputVarPID]
RunAs;[, User, Password, Domain]
RunWait;, Target [, WorkingDir, Max|Min|Hide|UseErrorLevel, OutputVarPID]
Seek;(Distance [, Origin = 0])
SendLevel;, Level
SendMessage;, Msg [, wParam, lParam, Control, WinTitle, WinText, ExcludeTitle, ExcludeText, Timeout]
SetBatchLines;, 20ms
SetBatchLines;, LineCount
SetCapacity;(MaxItems)
SetCapacity;(Key, ByteSize)
SetCapsLockState;[, State]
SetControlDelay;, Delay
SetDefaultMouseSpeed;, Speed
SetEnv;, Var, Value
SetFormat;, NumberType, Format
SetKeyDelay;[, Delay, PressDuration, Play]
SetMouseDelay;, Delay [, Play]
SetNumLockState;[, State]
SetRegView;, RegView
SetScrollLockState;[, State]
SetStoreCapslockMode;, On|Off
SetTimer;[, Label, Period|On|Off|Delete, Priority]
SetTitleMatchMode;, MatchMode
SetTitleMatchMode;, Fast|Slow
SetWinDelay;, Delay
SetWorkingDir;, DirName
Shutdown;, Code
Sin;(Number)
Sleep;, DelayInMilliseconds
Sort;, VarName [, Options]
SoundBeep;[, Frequency, Duration]
SoundGet;, OutputVar [, ComponentType, ControlType, DeviceNumber]
SoundGetWaveVolume;, OutputVar [, DeviceNumber]
SoundPlay;, Filename [, wait]
SoundSet;, NewSetting [, ComponentType, ControlType, DeviceNumber]
SoundSetWaveVolume;, Percent [, DeviceNumber]
SplashImage;, Off
SplashImage;[, ImageFile, Options, SubText, MainText, WinTitle, FontName]
SplashTextOn;[, Width, Height, Title, Text]
SplitPath;, InputVar [, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive]
Sqrt;(Number)
StatusBarGetText;, OutputVar [, Part#, WinTitle, WinText, ExcludeTitle, ExcludeText]
StatusBarWait;[, BarText, Seconds, Part#, WinTitle, WinText, Interval, ExcludeTitle, ExcludeText]
StrGet;(Address [, Length] [, Encoding = None ] )
StringCaseSense;, On|Off|Locale
StringGetPos;, OutputVar, InputVar, SearchText [, L#|R#, Offset]
StringLeft;, OutputVar, InputVar, Count
StringLen;, OutputVar, InputVar
StringLower;, OutputVar, InputVar [, T]
StringMid;, OutputVar, InputVar, StartChar [, Count , L]
StringReplace;, OutputVar, InputVar, SearchText [, ReplaceText, ReplaceAll?]
StringRight;, OutputVar, InputVar, Count
StringSplit;, OutputArray, InputVar [, Delimiters, OmitChars]
StringTrimLeft;, OutputVar, InputVar, Count
StringTrimRight;, OutputVar, InputVar, Count
StringUpper;, OutputVar, InputVar [, T]
StrLen;(InputVar)
StrPut;(String [, Encoding = None ] )
StrPut;(String, Address [, Length] [, Encoding = None ] )
SubStr;(String, StartingPos [, Length])
Suspend;[, Mode]
SysGet;, OutputVar, Sub-command [, Param3]
Tan;(Number)
Tell;()
Thread;, NoTimers [, false]
Thread;, Priority, n
Thread;, Interrupt [, Duration, LineCount]
Throw;[, Expression]
ToolTip;[, Text, X, Y, WhichToolTip]
Transform;, OutputVar, Cmd, Value1 [, Value2]
TrayTip;[, Title, Text, Seconds, Options]
Trim;(String, OmitChars = " `t")
UrlDownloadToFile;, URL, Filename
VarSetCapacity;(UnquotedVarName [, RequestedCapacity, FillByte])
WinActivate;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinActivateBottom;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinActive;("WinTitle", "WinText", "ExcludeTitle", "ExcludeText")
WinClose;[, WinTitle, WinText, SecondsToWait, ExcludeTitle, ExcludeText]
WinExist;("WinTitle", "WinText", "ExcludeTitle", "ExcludeText")
WinGet;, OutputVar [, Cmd, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinGetActiveStats;, Title, Width, Height, X, Y
WinGetActiveTitle;, OutputVar
WinGetClass;, OutputVar [, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinGetPos;[, X, Y, Width, Height, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinGetText;, OutputVar [, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinGetTitle;, OutputVar [, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinHide;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinKill;[, WinTitle, WinText, SecondsToWait, ExcludeTitle, ExcludeText]
WinMaximize;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinMenuSelectItem;, WinTitle, WinText, Menu [, SubMenu1, SubMenu2, SubMenu3, SubMenu4, SubMenu5, SubMenu6, ExcludeTitle, ExcludeText]
WinMinimize;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinMove;, X, Y
WinMove;, WinTitle, WinText, X, Y [, Width, Height, ExcludeTitle, ExcludeText]
WinRestore;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinSet;, Attribute, Value [, WinTitle, WinText,  ExcludeTitle, ExcludeText]
WinSetTitle;, NewTitle
WinSetTitle;, WinTitle, WinText, NewTitle [, ExcludeTitle, ExcludeText]
WinShow;[, WinTitle, WinText, ExcludeTitle, ExcludeText]
WinWait;[, WinTitle, WinText, Seconds, ExcludeTitle, ExcludeText]
WinWaitActive;[, WinTitle, WinText, Seconds, ExcludeTitle, ExcludeText]
WinWaitClose;[, WinTitle, WinText, Seconds, ExcludeTitle, ExcludeText]
WinWaitNotActive;[, WinTitle, WinText, Seconds, ExcludeTitle, ExcludeText]
Write;(String)
WriteLine;([String])
WriteNumType;(Num)
)
return
