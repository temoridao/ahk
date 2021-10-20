/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
 */

/**
 * Make your class a Singletone [https://en.wikipedia.org/wiki/Singleton_pattern]
 *
 * Derive your custom class from SingletonBase to make your class a singleton.
 * You will be able to use your class like `YourClass.Instance.yourMethod()`
 *
 * @see SuperGlobalSingleton
*/
class SingletonBase {
	__NewInit := SingletonBase.__New.Call(this)

	__New(){
		if (this._Instance != -1){
			throw "Trying to instantiate singleton class '" this.__Class "'"
		}
	}

	Instance[]
	{
		get {
			if (!this.HasKey("_Instance")){
				this._Instance := -1
				c := this.__Class
				this._Instance := new %c%()
			}
			return this._Instance
		}
	}
}
