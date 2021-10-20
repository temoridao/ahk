/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/

/**
 * Rejects adding of new properties to the derived class and throws exception on attempt
 * to call non-existent methods
 *
 * This class is useful to catch subtle errors when creating/using your own classes. Just inherit
 * your class from StaticClassBase
 *
 */
class StaticClassBase {

;public:
	getFuncObj(methodName, params*) {
		return ObjBindMethod(this, methodName, params*)
	}

;protected:
	__Set(key, value) {
		throw "Attempt to set '" this.__Class "." key "' => '" value "' REJECTED!"
		return
	}

	__Call(methodName, args*) {
		if (!IsFunc(this[methodName])) {
			throw "Couldn't find method '" methodName "' in '" this.__Class "' !"
		}
	}
}
