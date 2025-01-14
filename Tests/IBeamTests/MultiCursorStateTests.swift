import Foundation
import Testing

import IBeam

extension MultiCursorState where System == MockTextSystem {
	convenience init(string: String, textRanges: [(NSRange, CGFloat, SelectionAffinity?)]) {
		self.init(
			cursors: textRanges.map { Cursor($0.0, alignment: $0.1, affinity: $0.2) },
			system: MockTextSystem(string)
		)
	}

	convenience init(string: String, textRanges: [NSRange]) {
		self.init(
			string: string,
			textRanges: textRanges.map({ ($0, 0.0, nil) })
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

		try state.apply(.insertText("z"))

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
			.boundingRect(nil),

			.position(5),
			.boundingRect(nil),

			.position(6),
			.boundingRect(nil),
		]

		try state.apply(.deleteBackwards(.character))

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
			.boundingRect(nil),
			.position(7),
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
		]

		try state.apply(.moveLeft(.character))

		let expectedCursorRanges = [
			NSRange(1..<1),
			NSRange(7..<7),
			NSRange(9..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveLeftByCharacterSelectionOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 0.0, nil),
				(NSRange(8..<8), 0.0, nil),
				(NSRange(10..<10), 0.0, nil),
				(NSRange(13..<13), 0.0, .downstream)
			]
		)

		state.textSystem.responses = [
			.position(0),
			.boundingRect(nil),
			.position(7),
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
			.position(12),
			.boundingRect(nil),
		]

		try state.apply(.moveLeft(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(0..<3),
			NSRange(7..<8),
			NSRange(9..<10),
			NSRange(12..<13),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.cursors[3].affinity == .upstream)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveRightByCharacterOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
			.position(11),
			.boundingRect(nil),
		]

		try state.apply(.moveRight(.character, selecting: false))

		let expectedCursorRanges = [
			NSRange(3..<3),
			NSRange(9..<9),
			NSRange(11..<11),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveRightByCharacterSelectionOperation() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 0.0, nil),
				(NSRange(8..<8), 0.0, nil),
				(NSRange(10..<10), 0.0, nil),
				(NSRange(13..<13), 0.0, .upstream)
			]
		)

		state.textSystem.responses = [
			.position(4),
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
			.position(11),
			.boundingRect(nil),
			.position(14),
			.boundingRect(nil),
		]

		try state.apply(.moveRight(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(1..<4),
			NSRange(8..<9),
			NSRange(10..<11),
			NSRange(13..<14),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.cursors[3].affinity == .downstream)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveRightByCharacterSelectionOperationWithUpstreamAffinity() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 0.0, .upstream),
				(NSRange(8..<8), 0.0, .upstream),
			]
		)

		state.textSystem.responses = [
			.position(2),
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
		]

		try state.apply(.moveRight(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(2..<3),
			NSRange(8..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveRightByCharacterSelectionOperationWithDownstreamAffinity() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 0.0, .downstream),
				(NSRange(8..<8), 0.0, .downstream),
			]
		)

		state.textSystem.responses = [
			.position(4),
			.boundingRect(nil),
			.position(9),
			.boundingRect(nil),
		]

		try state.apply(.moveRight(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(1..<4),
			NSRange(8..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func newMoveDownByCharacterOperation() throws {
		// This is more complex. Let's assume "a" is 2.0 wide, and all others are 1
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(1..<3), 2.0, nil),
			]
		)

		state.textSystem.responses = [
			.position(7),
		]

		try state.apply(.moveDown)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(7..<7), 2.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.alignment } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}
}
