/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

/**
 * RAII [https://en.wikipedia.org/wiki/RAII] guard class which simply calls function passed to
 *    __New() inside its __Delete()
 *
 * The guard can be disarmed by calling dismiss() method
 *
 * @code{.ahk}
   #include <ScopeGuard>

   Clipboard := "Hello"
   someFuncWhichUsesClipboard()
   MsgBox % "Is Clipboard still contains ""Hello""? " (Clipboard = "Hello" ? "Yes" : "No")

   someFuncWhichUsesClipboard() {
   	;Ensure clipboard will be restored to the original value after function returns
   	clipGuard := new ScopeGuard(Func("restoreClipboard").Bind(Clipboard))
   	Clipboard := "Inside Function"
   	MsgBox % "Clipboard contains: """ Clipboard """"
   }
   restoreClipboard(restoreWith) {
   	Clipboard := restoreWith
   }
 * @endcode
*/
class ScopeGuard {
	__New(functor) {
		this.m_functor := functor
	}

	dismiss() {
		this.m_active := false
	}

;private:
	__Delete() {
		if (this.m_active) {
			this.m_functor.Call()
		}
	}

	m_functor := ""
	m_active := true
}