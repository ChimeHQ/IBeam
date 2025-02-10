import Foundation
import Testing
import IBeam

class MockState {
	var value: Int
	weak var undoManager: UndoManager?
	var handler: ((Int) -> Void)?

	init(value: Int, undoManager: UndoManager) {
		self.value = value
		self.undoManager = undoManager
	}

	func setValue(to newValue: Int) {
		let original = value

		undoManager?.registerUndo(withTarget: self) { target in
			target.setValue(to: original)
		}

		handler?(newValue)

		self.value = newValue
	}
}

struct UndoManagerActionTests {
	@Test
	func undoWithGroup() {
		let manager = UndoManager()
		nonisolated(unsafe) let state = MockState(value: 1, undoManager: manager)
		nonisolated(unsafe) var events = [String]()

		state.handler = { events.append(String($0)) }

		let actions = UndoManager.GroupActions<MockState>(
			enter: { _ in events.append("begin") },
			leave: { _ in events.append("end") }
		)

		actions.withUndoGrouping(for: manager, target: state) {
			state.setValue(to: 2)
			state.setValue(to: 3)
		}

		#expect(events == ["begin", "2", "3", "end"])

		events.removeAll()
		manager.undo()

		#expect(events == ["begin", "2", "1", "end"])

		events.removeAll()
		manager.redo()

		#expect(events == ["begin", "2", "3", "end"])

		events.removeAll()
		manager.undo()

		#expect(events == ["begin", "2", "1", "end"])
	}
}
