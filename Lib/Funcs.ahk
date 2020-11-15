/**
 * @file
 * Contains basic utitlity functions primarily enhancing standard AutoHotkey functions/commands
 *
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\..\3rdparty\Lib\Functions.ahk

/**
 * Get value bounded between minimum and maximum
 *
 * Throws an exception if @p min > @p max
 *
 * @param   v    The value
 * @param   min  The minimum
 * @param   max  The maximum
 *
 * @return  If @p v compares less than @p min, returns @p min; otherwise if @p max compares less
 *          than @p v, returns @p max; otherwise returns @p v
 */
Clamp(v, min, max) {
	if (min > max) {
		Throw "Invalid parameters: min > max"
	}

	return v < min ? min
	     : v > max ? max
	     : v
}

/**
 * Check if object has value (complement for built-in HasKey() method)
 *
 * @code{.ahk}
   MsgBox % HasVal(["orange", "banana", "apple"], "banana") ; Outputs "2"
 * @endcode
 *
 * @param   obj     The object to check value presence in
 * @param   needle  The needle value
 *
 * @return  First key in @p obj which has value equal to @p needle. 0 returned if nothing found
 */
HasVal(ByRef obj, ByRef needle) {
	for index, value in obj {
		if (value = needle) {
			Return index
		}
	}

	Return 0
}

/**
 * Removes a value from linear array
 *
 * @param   linearArrayObj  The linear array object from which a value will be removed
 * @param   val             The value to be removed from array (if found)
 *
 * @return  @c true if the first occurrence of @p val was removed, @c false otherwise
 */
RemoveVal(ByRef linearArrayObj, ByRef val) {
	if (pos := HasVal(linearArrayObj, val)) {
		linearArrayObj.RemoveAt(pos)
		return true
	}

	return false
}

/**
 * Resolve absolute path from relative
 *
 * @param   path  The path, possibly relative or with ".."
 *
 * @return  The absolute path resolved from @p path
 */
GetFullPathName(path) {
	cc := DllCall("GetFullPathName", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
	VarSetCapacity(buf, cc * (A_IsUnicode ? 2: 1))
	DllCall("GetFullPathName", "str", path, "uint", cc, "str", buf, "ptr", 0, "uint")
	return buf
}

/**
 * Sort array object
 *
 * @param   arr      The array object
 * @param   options  Sorting options similar to builit-in 'Sort' command
 *
 * @return  Sorted copy of @p arr according to @p options, or empty array if error occurs
 */
sortArray(arr, options:="") {
	if (!IsObject(arr)) {
		throw "Object expected"
	}

	list := ""
	for i, item in arr {
		list .= item "`n"
	}

	list := Trim(list, "`n")
	Sort list, %options%

	result := []
	Loop Parse, list, `n
		result.Push(A_LoopField)
	return result
}

SplashImageOff() {
	SplashImage OFF
}

/**
 * Gets the command line positional parameter's value
 *
 * @param   parameterName  The parameter name
 * @param   defaultValue   The default value
 *
 * @return  The command line value next to @p parameterName or @p defaultValue if not found
 */
GetCmdParameterValue(parameterName, defaultValue := "") {
	value := defaultValue
	if (i := HasVal(A_Args, parameterName)) {
		if (A_Args.Length() > i) {
			value := A_Args[i+1]
		}
	}
	return value
}

FSend(keys) {
	return Func("Send").Bind(keys)
}
_F(funcName, params*) {
	return Func(funcName).Bind(params*)
}
}