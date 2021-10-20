/**
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

/**
 * Helper function which destroys global script objects in reverse order of creation, not in alphabetical as AutoHotkey
 * does.
 *
 * The objects to be destroyed must be manually specified in a global `__gGlobalObjectsOrder` array. Also, the function
 * must be registered as `OnExit` handler. See example below.
 * @code{.ahk}
   global g_aobj := new MyClass
   global g_zobj := new AnotherClassWhichUsesMyClass(g_aobj)
   ;
   ;---------------------------------------------End of auto-execute section--------------------------------------------
   ;

   ;__gGlobalObjectsOrder - array of global objects, in order of creation, which must be securely destroyed upon
   ;script exit. Array's variable name (__gGlobalObjectsOrder) is mandatory.

   ;Will be destroyed in reverse order, not in alphabetical as in standard AutoHotkey order of destruction.
   global __gGlobalObjectsOrder := [g_aobj, g_zobj]
   OnExit("DestroyGlobalObjects")

   class MyClass {
   	__Delete() {
   		MsgBox % this.base.__Class " is destroying"
   	}
   }
   class AnotherClassWhichUsesMyClass {
   	__New(aobj) {
   		this.aobj := aobj
   	}
   	__Delete() {
   		this.aobj := ""
   		MsgBox % this.base.__Class " is destroying"
   	}
   }
 * @endcode
 *
 * @param   exitReason  Similar to `OnExit`-registered function parameter
 * @param   exitCode    Similar to `OnExit`-registered function parameter
 *
 * @return  Similar to `OnExit`-registered function return value
 */
DestroyGlobalObjects(exitReason, exitCode) {
	;Destroy and free resources for global objects in reverse order of creation.
	len := __gGlobalObjectsOrder.Length()
	i := len
	Loop % len {
		obj := __gGlobalObjectsOrder.RemoveAt(i--)
		if (!IsObject(obj)) {
			continue
		}
		ptr := &obj, ObjAddRef(ptr), refCount := ObjRelease(ptr)
		; logDebug(Format("{}({:#x}) refCount: {}", obj.base.__Class, ptr, refCount))
		if (refCount > 2) {
			MsgBox 48, %A_ScriptName%, % A_ThisFunc ": invalid refcount (" refCount ") for object of type """ obj.base.__Class
			         . """ (someone still holds its reference). Expected 2 references (1 global and 1 local to this function)."
		}
		obj.__Delete(), obj := ""
	}
}