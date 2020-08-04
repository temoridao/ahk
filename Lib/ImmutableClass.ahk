/**
 * Description:
 *    Prohibits adding new properties to the derived class
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
class ImmutableClass {

;public:
	getFuncObj(methodName, params*) {
		return ObjBindMethod(this, methodName, params*)
	}

;protected:
	__Set(key, value) {
		throw "Attempt to set ``" this.__Class "." key "`` => ``" value "`` REJECTED!"
		return
	}

	__Call(methodName, args*) {
		if (!IsFunc(this[methodName])) {
			throw "Couldn't find method ``" methodName "`` in ``" this.__Class "``!"
		}
	}
}
