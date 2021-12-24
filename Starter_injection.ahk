;====================================Template for AutoHotkey script injection file======================================
;Create files with the following paths (or make your own) according to your use cases and place there any code you want
;and/or add custom hotkeys (`Hotkey` command is recommended because it creates hotkeys dynamically and does not end the
;auto-execute section thus allowing to merge multiple injection files).

;=========================================Shared set of optional injections=============================================
#include *i %A_LineFile%\..\Shared\Starter_injection_common.ahk     ;<== For both Starter.{ahk,exe}
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Shared\Starter_injection_compiled.ahk   ;<== For Starter.exe only
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Shared\Starter_injection_uncompiled.ahk ;<== For Starter.ahk only
;@Ahk2Exe-IgnoreEnd

;========================================Internal set of optional injections============================================
#include *i %A_LineFile%\..\Internal\Starter_injection_common.ahk
/*@Ahk2Exe-Keep
#include *i %A_LineFile%\..\Internal\Starter_injection_compiled.ahk
*/
;@Ahk2Exe-IgnoreBegin
#include *i %A_LineFile%\..\Internal\Starter_injection_uncompiled.ahk
;@Ahk2Exe-IgnoreEnd
;=======================================================================================================================