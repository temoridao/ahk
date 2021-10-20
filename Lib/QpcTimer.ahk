/**
 * @file
 * @copyright Dedicated to Public Domain. See UNLICENSE.txt for details
*/
/**
 * Measure time periods with high resolution OS timer (QueryPerformanceCounter)
 *
 * @code{.ahk}
   #include <QpcTimer>

   t := qpc()
   Sleep 500
   MsgBox % "Elapsed milliseconds: " t.elapsedMs()

   Sleep 600
   MsgBox % "Elapsed milliseconds: " t.restart()

   MsgBox % "Elapsed after restart: " t.elapsedMs()
 * @endcode
*/
class QpcTimer {
	__New() {
		frequency := 0
		DllCall("QueryPerformanceFrequency", "Int64*", frequency)
		this.m_frequency := frequency

		this.takeSnapshot()
	}

	elapsedMs() {
		now := 0
		DllCall("QueryPerformanceCounter", "Int64*", now)
		return (now - this.m_before) / this.m_frequency * 1000
	}

	restart() {
		elapsed := this.elapsedMs()
		this.takeSnapshot()
		return elapsed
	}

;private:
	takeSnapshot() {
		before := 0
		DllCall("QueryPerformanceCounter", "Int64*", before)
		this.m_before := before
	}

	m_frequency := m_before := 0
}

/**
 * Convenience factory function for QpcTimer class
 *
 * @return  New QpcTimer object instance
 */
qpc() {
	return new QpcTimer()
}