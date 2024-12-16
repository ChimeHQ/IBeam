import Foundation
import Testing

import IBeam

extension MultiCursorState where System == MockTextSystem {
	convenience init(string: String, textRanges: [(NSRange, CGFloat)]) {
		self.init(
			cursors: textRanges.map { Cursor($0.0, position: $0.1) },
			system: MockTextSystem(string)
		)
	}

	convenience init(string: String, textRanges: [NSRange]) {
		self.init(
			string: string,
			textRanges: textRanges.map({ ($0, 0.0)})
		)
	}
}

final class MultiCursorStateTests {
	typealias CursorState = MultiCursorState<MockTextSystem>

	@Test
	func newInsertOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.apply(.insertText("z"))

		let expectedCursorRanges = [
			NSRange(2..<2),
			NSRange(8..<8),
			NSRange(11..<11),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "aza\nbbbzb\nzcccc\n")
	}

	@Test
	func newDeleteBackwardsByCharacterOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.position(5),
			.position(6),
		]

		state.apply(.deleteBackwards(.character))

		let expectedCursorRanges = [
			NSRange(1..<1),
			NSRange(5..<5),
			NSRange(6..<6),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "aa\nbbbcccc\n")
	}

	@Test
	func newMoveLeftByCharacterOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.position(7),
			.position(9),
		]

		state.apply(.moveLeft(.character))

		let expectedCursorRanges = [
			NSRange(1..<1),
			NSRange(7..<7),
			NSRange(9..<9),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveDownByCharacterOperation() throws {
		// This is more complex. Let's assume "a" is 2.0 wide, and all others are 1
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 2.0),
			]
		)

		state.textSystem.responses = [
			.position(7),
		]

		state.apply(.moveDown)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(7..<7), 2.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.position } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}
}
