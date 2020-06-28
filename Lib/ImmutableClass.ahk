/**
 * Description:
 *    Prohibits adding new properties to the derived class
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/
class ImmutableClass {
	__Set(key, value) {
		throw "Attempt to set ``" this.__Class "." key "`` => ``" value "`` REJECTED!"
		return
	}
}
