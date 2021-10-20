/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/


/**
 * Destroy array of objects in sequential order
 */
class OrderedDestructor {
	/**
	 * The constructor
	 *
	 * @param   handles                  An array of objects for destruction in `OrderedDestructor::__Delete()`
	 * @param   reverseDestructionOrder  Is @p handles must be traversed in reverse order?
	 */
	__New(handles, reverseDestructionOrder := false) {
		this.m_handles := handles
		this.m_reverseDestructionOrder := reverseDestructionOrder
	}

	__Delete() {
		len := this.m_handles.Length()
		if (this.m_reverseDestructionOrder) {
			i := len
			Loop % len {
				this.m_handles[i--] := ""
			}
		} else {
			Loop % len {
				this.m_handles[A_Index] := ""
			}
		}
	}
}
