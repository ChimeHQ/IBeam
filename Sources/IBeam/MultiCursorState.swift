import Foundation

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

			let newCursor = Cursor<OtherRange>(id: cursor.id, textRange: otherRange, alignment: cursor.alignment)

			return .resetToSingle(newCursor)
		}
	}
}

public final class MultiCursorState<System: TextSystem> {
	public typealias TextRange = System.TextRange

	typealias Processor = InputOperationProcessor<System>

	public var cursors: [Cursor<TextRange>] {
		didSet {
			let current = Set(cursors.map({ $0.id }))
			let old = Set(oldValue.map({ $0.id }))

			let deleted = old.subtracting(current)
			let added = current.subtracting(old)
			let changed = current.intersection(old)

			cursorsChanged(added, deleted, changed)
		}
	}
	
	private var validRange = 0..<0
	private var leadingPendingOperations: [InputOperation] = []
	private var trailingPendingOperations: [InputOperation] = []
	private let processor: Processor

	/// Added, Deleted, Changed
	public var cursorsChanged: (Set<UUID>, Set<UUID>, Set<UUID>) -> Void = { _, _, _ in }

	public init(cursors: [Cursor<TextRange>], system: System) {
		self.cursors = cursors
		self.processor = Processor(textSystem: system)
	}

	public var textSystem: System {
		processor.textSystem
	}

	public var cursorSet: CursorSet<TextRange> {
		// this is very inefficient
		CursorSet(ranges: cursors.map({ $0.textRange }))
	}
}

extension MultiCursorState {
	public func apply(_ operation: InputOperation) {
		let priorityRange = processor.fullRange

		apply(operation, prioritizing: priorityRange)
	}

	public func apply(_ operation: InputOperation, prioritizing priorityRange: TextRange) {
		// for now, we're going to ignore the valid window

		var deltaSum = 0

		var deletedIndexes: [Int] = []

		var newCusors = cursors

		for index in newCusors.indices {
			var cursor = newCusors[index]

			guard let output = processor.apply(operation, to: cursor, delta: deltaSum) else {
				deletedIndexes.append(index)
				continue
			}

			// is it sufficient to just check the previous?
			if index > 0 {
				let prev = newCusors[index - 1]

				if textSystem.intersection(of: output.selection, with: prev.textRange) != nil {
					deletedIndexes.append(index)

					// and does it makes sense to do this?
					deltaSum += output.delta
					continue
				}
			}

			cursor.textRange = output.selection

			if operation.affectsAlignment {
				cursor.alignment = location(for: output.selection)
			}

			newCusors[index] = cursor

			deltaSum += output.delta
		}

		// I think this is bad...
		for index in deletedIndexes.reversed() {
			newCusors.remove(at: index)
		}

		self.cursors = newCusors
	}

	public func ensureOperationsProcessed() {
		ensureOperationsProcessed(for: processor.fullRange)
	}

	public func ensureOperationsProcessed(for range: TextRange) {

	}

}

extension MultiCursorState {
	private func location(for range: TextRange) -> CGFloat? {
		textSystem.boundingRect(for: range)?.origin.x
	}

	public func mutateCursors(with operation: CursorOperation<TextRange>) {
		switch operation {
		case var .resetToSingle(cursor):
			cursor.alignment = location(for: cursor.textRange)

			self.cursors = [cursor]
		case let .add(textRange):
			let alignment = location(for: textRange)
			let newCursor = Cursor(textRange, alignment: alignment)

			var newCursors = cursors

			// inserting at the right spot would be more efficient
			newCursors.append(newCursor)

			newCursors.sort { a, b in
				let aLower = processor.textSystem.positions(composing: a.textRange).0
				let bLower = processor.textSystem.positions(composing: b.textRange).0

				return processor.textSystem.compare(aLower, to: bLower) == .orderedAscending
			}

			self.cursors = newCursors
		case .addAbove:
			guard let cursor = cursors.first else { return }

			guard
				let textRange = textSystem.textRange(
					from: cursor.textRange,
					moving: .up(alignment: cursor.alignment),
					by: .character
				)
			else {
				fatalError()
			}

			let alignment = location(for: textRange)
			let newCursor = Cursor(textRange, alignment: alignment)

			self.cursors.insert(newCursor, at: 0)
		case .addBelow:
			guard let cursor = cursors.last else {
				return
			}

			guard
				let textRange = processor.textSystem.textRange(
					from: cursor.textRange,
					moving: .down(alignment: cursor.alignment),
					by: .character
				)
			else {
				fatalError()
			}

			let alignment = location(for: textRange)
			let newCursor = Cursor(textRange, alignment: alignment)

			self.cursors.append(newCursor)
		}
	}
}
