/**
 * @file
 * Helper to make your class a singleton.
 *
 * The __New() method below creates a singleton overwriting super-global class variable.
 * Details: https://www.autohotkey.com/boards/viewtopic.php?p=176521&sid=8ec30ce3f8837578d8b2a426adc6932a#p176521
 *
 * @code{.ahk}
   F12::MySingletonClass.myMethod()

   class MySingletonClass {
   	;You basically need only next 2 lines (in any order) inside your class definition to make it singleton
   	#include SuperGlobalSingleton.ahk
   	static __self := new MySingletonClass()

   	;Declare optional method for any initialization required. It will be called from __New()
   	__InitSingleton() {
   		this.myDataField := "Cool data"
   	}

   	;The rest of class definition as usual, with properties, methods, whatever...
   	myMethod() {
   		MsgBox % "Hello from MySingletonClass! MySingletonClass.myDataFiled is '" MySingletonClass.myDataField "'"
   	}
   }
 *
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */
/**
 * The constructor of your singleton which overrides super-global class variable.
 *
 * It should be #include'd/copied into your class unmodified. See documentation for this file
 * for code example
 */
__New() {
	if (this.__self) {
		return this.__self
	}

	classPath := StrSplit(this.base.__Class, ".")
	className := classPath.removeAt(1)
	if (classPath.Length() > 0) {
		%className%[classPath*] := this
	} else {
		%className% := this
	}

	if (ObjHasKey(this.base, "__InitSingleton")) {
		this.__InitSingleton()
	}
}
