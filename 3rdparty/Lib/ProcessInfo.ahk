; ProcessInfo.ahk - Function library to retrieve various application process informations:
; - Script's own process identifier
; - Parent process ID of a process (the caller application)
; - Process name by process ID (filename without path)
; - Thread count by process ID (number of threads created by process)
; - Full filename by process ID (GetModuleFileNameEx() function)
;
; Tested with AutoHotkey 1.1.32.0
;
; Created by HuBa
; Contact: http://www.autohotkey.com/forum/profile.php?mode=viewprofile&u=4693
;
; Portions of the script are based upon the GetProcessList() function by wOxxOm
; (http://www.autohotkey.com/forum/viewtopic.php?p=65983#65983)


GetCurrentProcessID() {
	Return DllCall("GetCurrentProcessId")  ; http://msdn2.microsoft.com/ms683180.aspx
}

GetProcessName(ProcessID) {
	SplitPath % GetModuleFileNameEx(ProcessId), outFileName
	return outFileName
}

GetCurrentParentProcessID() {
	Return GetParentProcessID(GetCurrentProcessID())
}

GetParentProcessID(ProcessID) {
	Return GetProcessInformation(ProcessID, "UInt", 4, A_PtrSize == 8 ? 32 : 24)  ; DWORD th32ParentProcessID
}

GetProcessThreadCount(ProcessID) {
	Return GetProcessInformation(ProcessID, "UInt", 4, A_PtrSize == 8 ? 28 : 20)  ; DWORD cntThreads
}

;{ The function retrieves a value of the field from the PROCESSENTRY32 structure of the specified process.
	;
	; Parameters:
	; - ProcessID - the PID of the process for which to retrieve the PROCESSENTRY32
	; information
	; - CallVariableType - type of value to get (~type of DllCall parameter)
	; - VariableCapacity - size of the buffer [in bytes] to which to retrieve the value
	; - DataOffset - how far from beginning of PROCESSENTRY32 structure to search for data
	;
	; Returns:
	; - th32DataEntry - a value read from PROCESSENTRY32 structure
	;
	; Remarks:
	; - values that are possible to read:
	; http://msdn.microsoft.com/en-us/library/windows/desktop/ms684839%28v=vs.85%29.aspx
	;
	; typedef struct tagPROCESSENTRY32 {
		; DWORD     dwSize;
		; DWORD     cntUsage;
		; DWORD     th32ProcessID;
		; ULONG_PTR th32DefaultHeapID;
		; DWORD     th32ModuleID;
		; DWORD     cntThreads;
		; DWORD     th32ParentProcessID;
		; LONG      pcPriClassBase;
		; DWORD     dwFlags;
		; TCHAR     szExeFile[MAX_PATH];
		; } PROCESSENTRY32, *PPROCESSENTRY32;

	; Output from Structor.ahk (with MSVC 2019):
	; 	VarSetCapacity(procEntry, A_PtrSize == 8 ? 568 : 556, 0)

	; 	dwSize := NumGet(procEntry, 0, "UInt")
	; 	cntUsage := NumGet(procEntry, 4, "UInt")
	; 	th32ProcessID := NumGet(procEntry, 8, "UInt")
	; 	th32DefaultHeapID := NumGet(procEntry, A_PtrSize == 8 ? 16 : 12, "UPtr")
	; 	th32ModuleID := NumGet(procEntry, A_PtrSize == 8 ? 24 : 16, "UInt")
	; 	cntThreads := NumGet(procEntry, A_PtrSize == 8 ? 28 : 20, "UInt")
	; 	th32ParentProcessID := NumGet(procEntry, A_PtrSize == 8 ? 32 : 24, "UInt")
	; 	pcPriClassBase := NumGet(procEntry, A_PtrSize == 8 ? 36 : 28, "Int")
	; 	dwFlags := NumGet(procEntry, A_PtrSize == 8 ? 40 : 32, "UInt")
	; 	szExeFile := NumGet(procEntry, A_PtrSize == 8 ? 304 : 296, "Char")

	; 	NumPut(dwSize, procEntry, 0, "UInt")
	; 	NumPut(cntUsage, procEntry, 4, "UInt")
	; 	NumPut(th32ProcessID, procEntry, 8, "UInt")
	; 	NumPut(th32DefaultHeapID, procEntry, A_PtrSize == 8 ? 16 : 12, "UPtr")
	; 	NumPut(th32ModuleID, procEntry, A_PtrSize == 8 ? 24 : 16, "UInt")
	; 	NumPut(cntThreads, procEntry, A_PtrSize == 8 ? 28 : 20, "UInt")
	; 	NumPut(th32ParentProcessID, procEntry, A_PtrSize == 8 ? 32 : 24, "UInt")
	; 	NumPut(pcPriClassBase, procEntry, A_PtrSize == 8 ? 36 : 28, "Int")
	; 	NumPut(dwFlags, procEntry, A_PtrSize == 8 ? 40 : 32, "UInt")
	; 	NumPut(szExeFile, procEntry, A_PtrSize == 8 ? 304 : 296, "Char")
;}
GetProcessInformation(ProcessID, CallVariableType, VariableCapacity, DataOffset) {
	static cSizeOfStruct := A_PtrSize == 8 ? 568 : 556 ; PROCESSENTRY32 structure -> http://msdn2.microsoft.com/ms684839.aspx

	hSnapshot := DLLCall("CreateToolhelp32Snapshot", "UInt", 2, "UInt", 0)  ; TH32CS_SNAPPROCESS = 2
	if (hSnapshot) {
		VarSetCapacity(pe32, cSizeOfStruct, 0)
		NumPut(cSizeOfStruct, &pe32, 0, "UInt")
		VarSetCapacity(th32ProcessID, 4, 0)
		if (DllCall("Kernel32.dll\Process32First" , "Ptr", hSnapshot, "Ptr", &pe32)) { ; http://msdn2.microsoft.com/ms684834.aspx
			Loop {
				th32ProcessID := NumGet(&pe32, 8)
				if (ProcessID = th32ProcessID) {
					VarSetCapacity(th32DataEntry, VariableCapacity, 0)
					th32DataEntry := NumGet(&pe32, DataOffset, CallVariableType)
					DllCall("CloseHandle", "Ptr", hSnapshot)  ; http://msdn2.microsoft.com/ms724211.aspx
					Return th32DataEntry
				}

				if (!DllCall("Process32Next" , "Ptr", hSnapshot, "Ptr", &pe32)) {  ; http://msdn2.microsoft.com/ms684836.aspx
					Break
				}
			}
		}

		DllCall("CloseHandle", "Ptr", hSnapshot)
	}
	Return "" ; Cannot find process
}

GetModuleFileNameEx(ProcessID) {
	; #define PROCESS_VM_READ           (0x0010)
	; #define PROCESS_QUERY_INFORMATION (0x0400)
	hProcess := DllCall( "OpenProcess", "UInt", 0x10|0x400, "Int", False, "UInt", ProcessID)
	if (ErrorLevel || !hProcess ) {
		Return
	}

	FileNameSize := 260 * (A_IsUnicode ? 2 : 1)
	VarSetCapacity(ModuleFileName, FileNameSize, 0)
	CallResult := DllCall("Psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", ModuleFileName, "UInt", FileNameSize)
	DllCall("CloseHandle", "Ptr", hProcess)
	Return ModuleFileName
}