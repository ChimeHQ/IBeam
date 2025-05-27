import Foundation

import Rearrange

public final class MultiCursorState<System: TextSystemInterface> {
	public typealias TextRange = System.TextRange
	public typealias CursorChangedHandler = (_ added: Set<UUID>, _ deleted: Set<UUID>, _ changed: Set<UUID>) -> Void
	public typealias InputOperationProgress = (_ operation: InputOperation, _ count: Int, _ total: Int) -> Int
	public typealias InputOperationCompleted = (_ operation: InputOperation) -> Void

	typealias Processor = InputOperationProcessor<System>

	private var validRange: TextRange
	private var leadingPendingOperations: [InputOperation] = []
	private var trailingPendingOperations: [InputOperation] = []
	private let processor: Processor
	private var buffering = false
	private var internalCursors: [Cursor<TextRange>] = []

	public var cursorsChanged: CursorChangedHandler = { _, _, _ in }
	public var undoManagerProvider: () -> UndoManager? = { nil }

	public init(cursors: [Cursor<TextRange>], system: System) {
		self.internalCursors = cursors
		self.processor = Processor(textSystem: system)
		self.validRange = system.fullDocumentRange
	}

	public var textSystem: System {
		processor.textSystem
	}

	public var cursorSet: CursorSet<TextRange> {
		// this is very inefficient
		CursorSet(ranges: internalCursors.map({ $0.textRange }))
	}

	private var undoManager: UndoManager? {
		undoManagerProvider()
	}

	public var cursors: [Cursor<TextRange>] {
		get {
			internalCursors
		}
		set {
			withCursorChanges(affectingContent: false) {
				self.internalCursors = newValue
			}
		}
	}
}

extension MultiCursorState {
	/// Inform the cursor system that the underlying text has changed.
	public func didChangeText(in range: TextRange, delta: Int) {
	}

	private func validateOperation(_ operation: InputOperation) throws {
		// check bounds for an array-based insert
		if case .insertTextArray(let array) = operation {
			if array.count != internalCursors.count {
				throw CursorOperationError.insertArrayCountMismatch
			}
		}
	}

	private func apply(_ operation: InputOperation, at index: Int, delta: Int) -> (Int, Int)? {
		var newCursors = cursors
		var cursor = cursors[index]

		let perCursorOp = operation.indexedOperation(for: index)

		guard let output = try? processor.apply(perCursorOp, to: cursor, delta: delta) else {
			return nil
		}

		cursor.textRange = output.selection
		cursor.affinity = output.affinity

		if operation.affectsAlignment {
			cursor.alignment = location(for: output.selection)
		}

		newCursors[index] = cursor

		commitCursorChange(newCursors, affectsContent: operation.affectsContent)

		return (index, output.delta)
	}

	private func commitCursorChange(_ newCursors: [Cursor<System.TextRange>], affectsContent: Bool) {
		if let undoManager, affectsContent {
			nonisolated(unsafe) let cursorSnapshot = cursors

			undoManager.registerUndo(withTarget: self) { target in
				target.commitCursorChange(cursorSnapshot, affectsContent: true)
			}
		}

		self.internalCursors = newCursors
	}

	public func apply(_ operation: InputOperation) throws {
		let priorityRange = processor.fullRange

		try apply(operation, prioritizing: priorityRange)
	}

	public func apply(_ operation: InputOperation, prioritizing priorityTextRange: TextRange) throws {
		try validateOperation(operation)
		let affectsContent = operation.affectsContent

		withCursorChanges(affectingContent: affectsContent) {
			ensureOperationsProcessed(for: priorityTextRange)

			let priorityRange = CalculatedRange(priorityTextRange, calculator: textSystem)

			let firstAffected = internalCursors.firstIndex { cursor in
				let cursorLower = CalculatedPosition(cursor.textRange.lowerBound, calculator: textSystem)

				// if this cursor starts after our priority range, it is unaffected
				return cursorLower > priorityRange.upperBound
			}

			var index = firstAffected ?? internalCursors.startIndex
			var totalDelta = 0

			while index < internalCursors.endIndex {
				// this work can potentially change the number of cursors, so it turns
				// what index the input corresponds to.
				let (newIndex, delta) = apply(operation, at: index, delta: totalDelta) ?? (index, 0)

				index = newIndex
				totalDelta += delta

				index += 1
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
	private func withCursorChanges(affectingContent: Bool, _ block: () -> Void) {
		guard buffering == false else {
			block()
			return
		}

		self.buffering = true

		// set up the action we need to take on undo/redo
		let actions = UndoManager.GroupActions<MultiCursorState>(
			enter: { [textSystem] _ in
				textSystem.beginEditing()
			},
			leave: { [textSystem] target in
				textSystem.endEditing()

				// this is *only* necessary when undo operations are occuring
				guard target.undoManager?.isActive == true else { return }

				let currentSet = Set(self.internalCursors.map({ $0.id }))

				target.cursorsChanged(Set(), Set(), currentSet)
			}
		)

		// compute the old cursor set before taking any actions
		let old = Set(internalCursors.map({ $0.id }))

		// actually run the work, within the action group, but only if it affects content
		if affectingContent {
			actions.withUndoGrouping(for: undoManager, target: self, block)
		} else {
			block()
		}

		let current = Set(internalCursors.map({ $0.id }))

		handleChangedCursors(from: old, to: current)

		buffering = false
	}

	private func handleChangedCursors(from oldValue: Set<UUID>, to newValue: Set<UUID>) {
		let deleted = oldValue.subtracting(newValue)
		let added = newValue.subtracting(oldValue)
		let changed = newValue.intersection(oldValue)

		cursorsChanged(added, deleted, changed)
	}

	private func location(for range: TextRange) -> CGFloat? {
		textSystem.boundingRect(for: range)?.origin.x
	}

	public func mutateCursors(with operation: CursorOperation<TextRange>) {
		// I don't think the buffering is actually important here, but the diff calculation and change publishing is
		withCursorChanges(affectingContent: false) {
			unbufferedMutateCursors(with: operation)
		}
	}

	private func unbufferedMutateCursors(with operation: CursorOperation<TextRange>) {
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
			guard let cursor = internalCursors.first else { return }

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

			self.internalCursors.insert(newCursor, at: 0)
		case .addBelow:
			guard let cursor = internalCursors.last else {
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

			self.internalCursors.append(newCursor)
		}
	}
}
