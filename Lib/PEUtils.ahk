#include %A_LineFile%\..\ImmutableClass.ahk

class PEUtils extends ImmutableClass {
	/**
	 * Get build date for Exe/Dll file
	 *
	 * Determine build date of current AutoHotkey interpreter:
	 *
	 * @code{.ahk}
	 *  #include <PEUtils>
	 *
	 *  FormatTime formattedTime, % PEUtils.buildDate(A_AhkPath)
	 *  MsgBox % "AutoHotkey.exe build date: " formattedTime
	 * @endcode
	 *
	 * @param   PEfilePath  The PE file path (.exe or .dll for example)
	 *
	 * @return  Build date for Exe/Dll file
	 */
	buildDate(PEfilePath) {
		date := 1970
		f := FileOpen(PEfilePath, "r")
		if (!IsObject(f) || f.ReadUSHORT() != 0x5A4D) { ; Is IMAGE_DOS_HEADER.e_magic = 'MZ'?
			Return ""
		}

		f.Seek(60, 0)                                   ; Seek IMAGE_DOS_HEADER.e_lfanew
		f.Seek(f.ReadUINT(), 0)                         ; Seek IMAGE_NT_HEADERS
		if (f.ReadUINT() != 0x00004550) {               ; Is IMAGE_NT_HEADERS.Signature = 'PE'?
			Return ""
		}
		f.Seek(4, 1)                                    ; Seek IMAGE_FILE_HEADER.TimeDateStamp
		date += f.ReadUINT(), S
		Return date
	}

}