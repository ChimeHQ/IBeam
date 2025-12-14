import XCTest
import IBeam

final class MultiCursorStatePerformanceTests: XCTestCase {
	typealias CursorState = MultiCursorState<MockTextSystem>

	@MainActor
	func testLargeNumberOfCursors() throws {
		let count = 5000
		let baseString = "abcdef\n"
		let string = String(repeating: baseString, count: count)

		let options = XCTMeasureOptions()

		options.invocationOptions = [.manuallyStart]

		measure(options: options) {
			let state = MultiCursorState(
				string: string,
				textRanges: [NSRange]()
			)

			state.textSystem.responses = [
				.position(7),
			]

			// step 1, apply a cursor to every line
			let lineLength = baseString.utf16.count
			let cursors = (0..<count).map { i in
				let range = NSRange(location: i * lineLength, length: 0)

				return Cursor(range, alignment: nil, affinity: nil)
			}

			state.cursors = cursors

			startMeasuring()

			// first ten lines only
			let priorityRange = NSRange(0..<(lineLength*10))

			try! state.apply(.insertText("1"), prioritizing: priorityRange)
		}
	}
}
