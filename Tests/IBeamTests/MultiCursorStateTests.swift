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

@MainActor
struct MultiCursorStateTests {
	typealias CursorState = MultiCursorState<MockTextSystem>

	@Test
	func insert() throws {
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
	func insertTextArrayMatchingCursors() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.apply(.insertTextArray(["1", "2", "3"]))

		let expectedCursorRanges = [
			NSRange(2..<2),
			NSRange(8..<8),
			NSRange(11..<11),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "a1a\nbbb2b\n3cccc\n")
	}

	@Test
	func insertTextArrayBiggerThanCursors() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.position(10 + 5),
			.boundingRect(nil),
		]

		state.apply(.insertTextArray(["1", "2", "3", "4"]))

		let expectedCursorRanges = [
			NSRange(2..<2),
			NSRange(8..<8),
			NSRange(11..<11),
			NSRange(17..<17),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "a1a\nbbb2b\n3cccc\n4")
	}

	@Test
	func insertTextArraySmallerThanCursors() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.apply(.insertTextArray(["1", "2"]))

		let expectedCursorRanges = [
			NSRange(2..<2),
			NSRange(8..<8),
			NSRange(10..<10),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "a1a\nbbb2b\ncccc\n")
	}

	@Test
	func deleteBackwardsByCharacter() throws {
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

			.position(8 - 2 - 1),
			.boundingRect(nil),

			.position(10 - 2 - 2),
			.boundingRect(nil),
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
	func deleteBackwardsByLine() throws {
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

			.position(8 - 2 - 3),
			.boundingRect(nil),

			.position(10 - 2 - 3),
			.boundingRect(nil),
		]

		state.apply(.deleteBackwards(.line))

		let expectedCursorRanges = [
			NSRange(1..<1),
			NSRange(3..<3),
			NSRange(5..<5),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursorRanges)
		#expect(state.textSystem.string == "aa\nb\ncccc\n")
	}

	@Test
	func moveLeftByCharacter() throws {
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

		state.apply(.moveLeft(.character))

		let expectedCursorRanges = [
			NSRange(1..<1),
			NSRange(7..<7),
			NSRange(9..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func moveLeftByCharacterSelection() throws {
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

		state.apply(.moveLeft(.character, selecting: true))

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
	func moveRightByCharacterOperation() throws {
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

		state.apply(.moveRight(.character, selecting: false))

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

		state.apply(.moveRight(.character, selecting: true))

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
	func moveRightByCharacterSelectionOperationWithUpstreamAffinity() throws {
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

		state.apply(.moveRight(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(2..<3),
			NSRange(8..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func moveRightByCharacterSelectionOperationWithDownstreamAffinity() throws {
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

		state.apply(.moveRight(.character, selecting: true))

		let expectedCursorRanges = [
			NSRange(1..<4),
			NSRange(8..<9),
		]
		#expect(state.cursorSet.ranges == expectedCursorRanges)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func moveDownByCharacterOperation() throws {
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

		state.apply(.moveDown)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(7..<7), 2.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.alignment } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func moveToEndOfDocument() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.position(15),
			.boundingRect(nil),
		]

		state.apply(.moveToEndOfDocument(selecting: false))

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(15..<15), 0.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func moveToBeginningOfDocument() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				NSRange(1..<3),
				NSRange(8..<8),
				NSRange(10..<10),
			]
		)

		state.textSystem.responses = [
			.position(0),
		]

		state.apply(.moveToBeginningOfDocument(selecting: false))

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(0..<0), 0.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}
}

extension MultiCursorStateTests {
	@Test
	func undoAndRedoInsert() throws {
		let undoManager = UndoManager()

		var events = [String]()

		// set random alignments/affinity just to validate they are restored
		let originalCursors: [Cursor<CursorState.TextRange>] = [
			Cursor(NSRange(1..<3), alignment: 1.0, affinity: .upstream),
			Cursor(NSRange(8..<8), alignment: nil, affinity: .upstream),
			Cursor(NSRange(10..<10), alignment: 1.0, affinity: nil),
		]

		let system = MockTextSystem("aaaa\nbbbb\ncccc\n")
		let state = MultiCursorState(
			cursors: originalCursors,
			system: system
		)

		var mutationCount = 0

		state.undoManagerProvider = { undoManager }
		system.undoManagerProvider = { undoManager }
		system.willApplyMutation = { _, _ in
			events.append("m-\(mutationCount)")

			mutationCount += 1
		}

		system.willBeginEditing = { events.append("b") }
		system.didEndEditing = { events.append("e") }

		var changeCount = 0
		state.cursorsChanged = { added, deleted, changed in
			events.append("c-\(changeCount)")
			changeCount += 1

			#expect(added.isEmpty)
			#expect(deleted.isEmpty)
			#expect(changed == Set(originalCursors.map(\.id)))
		}

		state.apply(.insertText("z"))

		var expectedCursors = originalCursors
		expectedCursors[0].textRange = NSRange(2..<2)
		expectedCursors[0].affinity = nil
		expectedCursors[0].alignment = nil
		expectedCursors[1].textRange = NSRange(8..<8)
		expectedCursors[1].affinity = nil
		expectedCursors[2].textRange = NSRange(11..<11)
		expectedCursors[2].alignment = nil

		// this is really annoying, but is is *critical* we validate the ordering of events during undo and redo.
		#expect(events == ["b", "m-0", "m-1", "m-2", "e", "c-0"])
		#expect(state.cursors == expectedCursors)
		#expect(state.textSystem.string == "aza\nbbbzb\nzcccc\n")

		events.removeAll()
		undoManager.undo()

		#expect(events == ["b", "m-3", "m-4", "m-5", "e", "c-1"])
		#expect(state.cursors == originalCursors)
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")

		events.removeAll()
		undoManager.redo()

		#expect(events == ["b", "m-6", "m-7", "m-8", "e", "c-2"])
		#expect(state.cursors == expectedCursors)
		#expect(state.textSystem.string == "aza\nbbbzb\nzcccc\n")
	}
}

extension MultiCursorStateTests {
	@Test
	func addCursorAbove() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(6..<6), 5.0, nil),
			]
		)

		state.textSystem.responses = [
			.position(1),
			.boundingRect(CGRect(x: 4.0, y: 0.0, width: 0.0, height: 0.0)),
		]

		state.mutateCursors(with: .addAbove)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(1..<1), 4.0),
			(NSRange(6..<6), 5.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.alignment } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func addCursorBelow() throws {
		let state = MultiCursorState(
			string: "aaaa\nbbbb\ncccc\n",
			textRanges: [
				(NSRange(6..<6), 5.0, nil),
			]
		)

		state.textSystem.responses = [
			.position(11),
			.boundingRect(CGRect(x: 6.0, y: 10.0, width: 0.0, height: 0.0)),
		]

		state.mutateCursors(with: .addBelow)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(6..<6), 5.0),
			(NSRange(11..<11), 6.0),
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.alignment } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\nbbbb\ncccc\n")
	}

	@Test
	func addCursorBelowToNonexistantRange() throws {
		let state = MultiCursorState(
			string: "aaaa\n",
			textRanges: [
				(NSRange(1..<1), 5.0, nil),
			]
		)

		state.textSystem.responses = [
			.position(nil)
		]

		state.mutateCursors(with: .addBelow)

		let expectedCursors: [(NSRange, CGFloat)] = [
			(NSRange(1..<1), 5.0)
		]
		#expect(state.cursors.map { $0.textRange } == expectedCursors.map({ $0.0 }))
		#expect(state.cursors.map { $0.alignment } == expectedCursors.map({ $0.1 }))
		#expect(state.textSystem.string == "aaaa\n")

	}
}
