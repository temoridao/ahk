/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */
/**
 * Collects text input
 *
 * Collected text accessible through `text()` method of the class.
 *
 * @note All `[:cntrl:]` characters (except new line) are ignored
 *
 * @code{.ahk}
   #include <TextInputCollector> ; Assuming TextInputCollector.ahk is in your Lib folder

   ;Create new input collector and start it
   inputCollector := new TextInputCollector()
   inputCollector.start()

   ;Win+Shift+i - display collected text input
   #+i::MsgBox % inputCollector.text()
 * @endcode
*/
class TextInputCollector {
	lastWord() {
		RegexMatch(this.m_textInputBuffer, TextInputCollector.sLastWordRegex, m)
		return m.value()
	}
	setLastWord(lw) {
		this.m_textInputBuffer := RegexReplace(this.m_textInputBuffer, TextInputCollector.sLastWordRegex, lw)
	}

	text() {
		return this.m_textInputBuffer
	}
	setText(newText) {
		this.m_textInputBuffer := newText
	}

	start() {
		this.setupInputHook()
	}
	stop() {
		this.m_textInputHook.Stop()
	}

	__Delete() {
		this.stop()
	}

;private:
	static sLastWordRegex := "OS)\S+\s*$"
	OnKeyDown(instanceAddress, hook, VK, SC) {
		keyName := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
		if (StrLen(keyName) = 1)
			return
		; logDebug("keyName: {}", keyName)
		this := object(instanceAddress)

		static ignoredKeys := "i)Space|Tab|Enter|Shift|Caps|Delete"
		if (keyName = "Backspace") {
			this.m_textInputBuffer := SubStr(this.m_textInputBuffer, 1, StrLen(this.m_textInputBuffer) - 1)
		} else if (!(keyName ~= ignoredKeys)) {
			this.m_textInputBuffer := ""
		}
	}
	OnCharacterTyped(instanceAddress, hook, char) {
		this := object(instanceAddress)
		if (asc(char) = 10) { ; {Enter} key
			this.m_textInputBuffer .= "`r`n"
		} else if (char ~= "[^[:cntrl:]]") { ;All characters except control chars (see "POSIX character class" for more info)
			; logDebug("char: " quote(char) " (code: " asc(char) ")")
			this.m_textInputBuffer .= char
		}
	}

	setupInputHook() {
		;L0 - Disable hook's internal text buffer (we'll collect useful text in OnChar callback)
		;I - set MinSendLevel to 1, i.e. ignores artificial input produced by AutoHotkey (which defaults to 0 SendLevel)
		this.m_textInputHook := InputHook("L0")

		this.m_textInputHook.VisibleText := true ;Allow text characters to be propagated to consumers (do not block them)
		this.m_textInputHook.OnChar := ObjBindMethod(this.base, "OnCharacterTyped", &this)

		this.m_textInputHook.KeyOpt("{All}", "N")
		this.m_textInputHook.OnKeyDown := ObjBindMethod(this.base, "OnKeyDown", &this)
		this.m_textInputHook.Start()
	}

	m_textInputHook := ""
	m_textInputBuffer := ""
}