import Testing
import IBeam

import Ligature

final class MultiCursorStateTests {
	@Test @MainActor
	func addCursorBelow() throws {
		let cursor = Cursor(range: 0..<10)
		let tokenizer = MockTextTokenizer()
		let state = MultiCursorState(cursors: [cursor], tokenizer: tokenizer)

		tokenizer.responses = [.position(5), .position(15)]
		state.addCursorBelow()

		#expect(tokenizer.requests == [.position(0, .character, .layout(.down)), .position(10, .character, .layout(.down))])
		#expect(state.cursors.map(\.range) == [0..<10, 5..<15])
	}

	@Test @MainActor
	func handleLeftArrowWithSingleInsertion() throws {
		let cursor = Cursor(range: 1..<1)
		let tokenizer = MockTextTokenizer()
		let state = MultiCursorState(cursors: [cursor], affinity: .upstream, tokenizer: tokenizer)

		tokenizer.responses = [.position(0)]
		state.moveLeft(nil)

		#expect(tokenizer.requests == [.position(1, .character, .layout(.left))])
		#expect(state.cursors.map(\.range) == [0..<0])
	}
}
