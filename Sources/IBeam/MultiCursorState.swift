import Foundation

import Rearrange

extension UndoManager {
	enum Direction {
		case any
		case undo
		case redo

		var reverse: Direction {
			switch self {
			case .any: .any
			case .undo: .redo
			case .redo: .undo
			}
		}
	}

	func active(in direction: Direction) -> Bool {
		switch direction {
		case .any:
			isUndoing || isRedoing
		case .undo:
			isUndoing
		case .redo:
			isRedoing
		}
	}
}

public enum CursorOperationError: Error {
	case insertArrayCountMismatch
}

public enum CursorOperation<TextRange> {
	case resetToSingle(Cursor<TextRange>)
	case add(TextRange)
	case addAbove
	case addBelow

	// this is nearly a map
	public func translate<OtherRange>(with translator: (TextRange) -> OtherRange?) -> CursorOperation<OtherRange>? {
		switch self {
		case .addAbove:
			return .addAbove
		case .addBelow:
			return .addBelow
		case let .add(textRange):
			guard let otherRange = translator(textRange) else {
				return nil
			}
			
			return .add(otherRange)
		case let .resetToSingle(cursor):
			guard let otherRange = translator(cursor.textRange) else {
				return nil
			}
			
			let newCursor = Cursor<OtherRange>(
				id: cursor.id,
				textRange: otherRange,
				alignment: cursor.alignment,
				affinity: cursor.affinity
			)
			
			return .resetToSingle(newCursor)
		}
	}
}

public final class MultiCursorState<System: TextSystemInterface> {
	public typealias TextRange = System.TextRange

	typealias Processor = InputOperationProcessor<System>

	public var cursors: [Cursor<TextRange>] {
		didSet {
//			let current = Set(cursors.map({ $0.id }))
//			let old = Set(oldValue.map({ $0.id }))
//
//			let deleted = old.subtracting(current)
//			let added = current.subtracting(old)
//			let changed = current.intersection(old)
//
//			cursorsChanged(added, deleted, changed)
		}
	}
	
	private var validRange: TextRange
	private var leadingPendingOperations: [InputOperation] = []
	private var trailingPendingOperations: [InputOperation] = []
	private let processor: Processor

	/// Added, Deleted, Changed
	public var cursorsChanged: (_ added: Set<UUID>, _ deleted: Set<UUID>, _ changed: Set<UUID>) -> Void = { _, _, _ in }
	public var undoManagerProvider: (() -> UndoManager?)?
	public var buffering = false

	public init(cursors: [Cursor<TextRange>], system: System) {
		self.cursors = cursors
		self.processor = Processor(textSystem: system)
		self.validRange = system.fullDocumentRange
	}

	public var textSystem: System {
		processor.textSystem
	}

	public var cursorSet: CursorSet<TextRange> {
		// this is very inefficient
		CursorSet(ranges: cursors.map({ $0.textRange }))
	}

	private var undoManager: UndoManager? {
		undoManagerProvider?()
	}
}

extension MultiCursorState {
	/// Inform the cursor system that the underlying text has changed.
	public func didChangeText(in range: TextRange, delta: Int) {
	}

	private func validateOperation(_ operation: InputOperation) throws {
		// check bounds for an array-based insert
		if case .insertTextArray(let array) = operation {
			if array.count != cursors.count {
				throw CursorOperationError.insertArrayCountMismatch
			}
		}
	}

	private func apply(_ operation: InputOperation, at index: Int) -> Int? {
		var newCursors = cursors
		var cursor = cursors[index]

		let perCursorOp = operation.indexedOperation(for: index)

		guard let output = processor.apply(perCursorOp, to: cursor, delta: 0) else {
			return nil
		}

		cursor.textRange = output.selection
		cursor.affinity = output.affinity

		if operation.affectsAlignment {
			cursor.alignment = location(for: output.selection)
		}

		newCursors[index] = cursor

		// now apply delta to following cursors that need it
		let delta = output.delta
		if delta != 0 {
			let start = min(index + 1, newCursors.endIndex)

			for i in start..<newCursors.endIndex {
				if let calRange = CalculatedRange(newCursors[i].textRange, calculator: textSystem).offset(by: delta) {
					newCursors[i].textRange = calRange.range
				}
			}
		}

		commitCursorChange(newCursors, withUndo: operation.supportsUndo)

		return index
	}

	private func commitCursorChange(_ newCursors: [Cursor<System.TextRange>], withUndo undoable: Bool) {
		if let undoManager, undoable {
			nonisolated(unsafe) let cursorSnapshot = cursors

			undoManager.registerUndo(withTarget: self) { target in
				target.commitCursorChange(cursorSnapshot, withUndo: true)
			}
		}

		self.cursors = newCursors
	}

	public func apply(_ operation: InputOperation) throws {
		let priorityRange = processor.fullRange

		try apply(operation, prioritizing: priorityRange)
	}

	public func apply(_ operation: InputOperation, prioritizing priorityTextRange: TextRange) throws {
		try validateOperation(operation)
		let undoable = operation.supportsUndo

		bufferCursorChanges(withUndo: undoable) {
			ensureOperationsProcessed(for: priorityTextRange)

			let priorityRange = CalculatedRange(priorityTextRange, calculator: textSystem)

			let lastAffected = cursors.lastIndex { cursor in
				let cursorLower = CalculatedPosition(cursor.textRange.lowerBound, calculator: textSystem)

				// if this cursor starts after our priority range, it is unaffected
				return cursorLower > priorityRange.upperBound
			}

			// we now walk backwards from the first
			var index = lastAffected ?? (cursors.endIndex - 1)

			while index >= 0 {
				index = apply(operation, at: index) ?? index

				index -= 1
			}
		}
	}

	public func ensureOperationsProcessed() {
		ensureOperationsProcessed(for: processor.fullRange)
	}

	public func ensureOperationsProcessed(for range: TextRange) {
//		bufferCursorChanges(withUndo: false) {
			// ...
//		}
	}

}

extension MultiCursorState {
	private func publishCurrentCursorStateForUndo(_ currentSet: Set<UUID>, direction: UndoManager.Direction) {
		guard let undoManager else { return }

		if undoManager.active(in: direction) {
			cursorsChanged(Set(), Set(), currentSet)
		}

		undoManager.registerUndo(withTarget: self) { target in
			let snapshotIdSet = Set(target.cursors.map({ $0.id }))

			target.publishCurrentCursorStateForUndo(snapshotIdSet, direction: direction)
		}
	}

	private func bufferCursorChanges(withUndo undoable: Bool, _ block: () -> Void) {
		if buffering {
			block()
			return
		}

		self.buffering = true
		let old = Set(cursors.map({ $0.id }))

		if undoable {
			undoManager?.beginUndoGrouping()

			publishCurrentCursorStateForUndo(old, direction: .undo)
		}

		block()

		let current = Set(cursors.map({ $0.id }))
		let deleted = old.subtracting(current)
		let added = current.subtracting(old)
		let changed = current.intersection(old)

		cursorsChanged(added, deleted, changed)

		if undoable {
			publishCurrentCursorStateForUndo(current, direction: .redo)

			undoManager?.endUndoGrouping()
		}

		buffering = false
	}

	private func location(for range: TextRange) -> CGFloat? {
		textSystem.boundingRect(for: range)?.origin.x
	}

	public func mutateCursors(with operation: CursorOperation<TextRange>) {
		bufferCursorChanges(withUndo: false) {
			switch operation {
			case var .resetToSingle(cursor):
				cursor.alignment = location(for: cursor.textRange)

				self.cursors = [cursor]
			case let .add(textRange):
				let alignment = location(for: textRange)
				let newCursor = Cursor(textRange, alignment: alignment, affinity: nil)

				var newCursors = cursors

				// inserting at the right spot would be more efficient
				newCursors.append(newCursor)
				newCursors.sort { a, b in
					let aLower = a.textRange.lowerBound
					let bLower = b.textRange.lowerBound

					return processor.textSystem.compare(aLower, to: bLower) == .orderedAscending
				}

				self.cursors = newCursors
			case .addAbove:
				guard let cursor = cursors.first else { return }

				let textRange = textSystem.textRange(
					from: cursor.textRange,
					moving: .up(alignment: cursor.alignment),
					by: .character
				)

				guard let textRange else {
					fatalError()
				}

				let alignment = location(for: textRange)
				let newCursor = Cursor(textRange, alignment: alignment, affinity: cursor.affinity)

				self.cursors.insert(newCursor, at: 0)
			case .addBelow:
				guard let cursor = cursors.last else {
					return
				}

				let textRange = processor.textSystem.textRange(
					from: cursor.textRange,
					moving: .down(alignment: cursor.alignment),
					by: .character
				)

				guard let textRange else {
					fatalError()
				}

				let alignment = location(for: textRange)
				let newCursor = Cursor(textRange, alignment: alignment, affinity: cursor.affinity)

				self.cursors.append(newCursor)
			}
		}
	}
}
