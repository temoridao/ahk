/* _________________________________________________________________________________________________
 ____                                                               _           ____   _      _
|  _ \  ___  ___   ___   _   _  _ __  ___  ___         ___   _ __  | | _   _   |  _ \ | |    | |
| |_) |/ _ \/ __| / _ \ | | | || '__|/ __|/ _ \ ____  / _ \ | '_ \ | || | | |  | | | || |    | |
|  _ <|  __/\__ \| (_) || |_| || |  | (__|  __/|____|| (_) || | | || || |_| |  | |_| || |___ | |___
|_| \_\\___||___/ \___/  \__,_||_|   \___|\___|       \___/ |_| |_||_| \__, |  |____/ |_____||_____|
                                                                        |___/
   Simple wrapper of 4 functions to create and use DLL resources in AutoHotkey Scripting Language
   By SKAN - Suresh Kumar A N  (arian.suresh@gmail.com)
   Created: 05-Sep-2010 / Last-Modified: 10-Sep-2017 / Version: 0.9 / Autohotkey 1.1

   Forum topic : https://autohotkey.com/boards/viewtopic.php?t=36201
   Old topic   : http://www.autohotkey.com/forum/viewtopic.php?t=62180
____________________________________________________________________________________________________
*/

DllPackFiles( Folder, DLL, Section := "Files" ) { ; By SKAN | goo.gl/DjDxzW
Local BIN, IX := 0, hUPD
  Section := Format( "{:U}", Section )
  DLL :=  FileExist( DLL ) ? DLL : DllCreateEmpty( DLL )
  VarSetCapacity(BIN, 128, 0 ), VarSetCapacity( BIN,0 )
  hUPD := DllCall( "BeginUpdateResource", "Str",DLL, "Int",0, "Ptr" )

  Loop, Files, %Folder%\*.*
  {
    Key := Format( "{:U}", A_LoopFileName )
    FileRead, BIN, *c %A_LoopFileLongPath%
    DllCall( "UpdateResource", "Ptr",hUPD, "Str",Section, "Str",Key
           , "Int",0, "Ptr",&BIN, "UInt",A_LoopFileSize )
  }
  DllCall( "EndUpdateResource", "Ptr",hUPD, "Int",0 )
}
;___________________________________________________________________________________________________

DllCreateEmpty( NewFile ) {                       ; By SKAN | goo.gl/DjDxzW
Local UNIXTIME := A_NowUTC, DLLBIN, Off, File
Local DLLHEX :=  "0X5A4DY3CXC0YC0X4550YC4X1014CYD4X210E00E0YD8XA07010BYE0X200YECX1000YF0X1000YF4X10"
   . "000YF8X1000YFCX200Y100X4Y108X4Y110X2000Y114X200Y11CX4000003Y120X40000Y124X1000Y128X100000Y12C"
   . "X1000Y134X10Y148X1000Y14CX10Y1B8X7273722EY1BCX63Y1C0X10Y1C4X1000Y1C8X200Y1CCX200Y1DCX40000040"

  UNIXTIME -= 1970, Seconds
  VarSetCapacity( DLLBIN, 1024, 0 ), Numput( UNIXTIME, DLLBIN, 200, "UInt" )
  Loop, Parse, DLLHEX, XY
    Mod( A_Index, 2 ) ? ( Off := "0x" A_LoopField ) : NumPut( "0x" A_LoopField, DLLBIN, Off, "Int" )
  File := FileOpen( NewFile, "w"),  File.RawWrite( DLLBIN, 1024 ),  File.Close()
Return NewFile
}
;___________________________________________________________________________________________________

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
;___________________________________________________________________________________________________

DllEnum( P1, P2, P3, P4 ) {                       ; By SKAN | goo.gl/DjDxzW
Local hMod, hGlobal
Static Section  :=   L := Prefix := Delim := ""
  If ( Section and ( L .= Prefix . StrGet(P3+0) . Delim ) )
      Return True
  Section := P2, Prefix := P3, Delim := P4
  hMod := DllCall( "LoadLibrary", "Str", P1, "Ptr" )
  hGlobal := RegisterCallback( A_ThisFunc, "F" )
  DllCall( "EnumResourceNames", "Ptr",hMod, "Str",P2, "Ptr",hGlobal, "UInt",123 )
  DllCall( "GlobalFree", "Ptr",hGlobal, "Ptr")
  DllCall( "FreeLibrary", "Ptr",hMod )
Return RTrim( L, Delim ) . ( Section := L := Prefix :=  Delim := "" )
}
;___________________________________________________________________________________________________