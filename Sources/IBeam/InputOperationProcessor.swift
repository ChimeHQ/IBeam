import Foundation

struct InputOperationProcessor<System: TextSystemInterface> {
	typealias CursorState = MultiCursorState<System>
	typealias TextRange = System.TextRange
	typealias Output = MutationOutput<TextRange>

	let textSystem: System

	public var fullRange: TextRange {
		textSystem.fullDocumentRange
	}

	public func apply(_ operation: InputOperation, to cursor: Cursor<TextRange>, delta: Int) -> Output? {
		// step one, apply delta
		guard let textRange = textSystem.textRange(offseting: cursor.textRange, by: delta) else {
			return nil
		}

		switch operation {
		case let .insertText(value):
			return textSystem.applyMutation(textRange, string: value)
		case let .deleteBackwards(value):
			return deleteBackwards(granularity: value, textRange: textRange)
		case let .moveLeft(granularity):
			return moveLeft(granularity: granularity, textRange: textRange)
		case let .moveRight(granularity):
			return moveRight(granularity: granularity, textRange: textRange)
		case .moveUp:
			return moveUp(textRange: textRange, alignment: cursor.alignment)
		case .moveDown:
			return moveDown(textRange: textRange, alignment: cursor.alignment)
		case .moveToRightEndOfLine:
			return moveToRightEndOfLine(textRange: textRange)
		case .moveToLeftEndOfLine:
			return moveToLeftEndOfLine(textRange: textRange)
		case .insertTextArray:
			fatalError("This operation cannot be processed on a per-cursor basis")
		}
	}

	private func deleteBackwards(granularity: TextGranularity, textRange: TextRange) -> Output? {
		let emptyString = AttributedString()
		let positions = textSystem.positions(composing: textRange)

		if textSystem.compare(positions.0, to: positions.1) == .orderedSame {
			guard
				let newLower = textSystem.position(from: positions.0, moving: .backward, by: granularity),
				let deleteRange = textSystem.textRange(from: newLower, to: positions.0)
			else {
				return nil
			}

			return textSystem.applyMutation(deleteRange, string: emptyString)
		}

		return textSystem.applyMutation(textRange, string: emptyString)
	}

	private func moveLeft(
		granularity: TextGranularity,
		textRange: TextRange
	) -> Output? {
		let positions = textSystem.positions(composing: textRange)

		if textSystem.compare(positions.0, to: positions.1) != .orderedSame {
			let pos = layoutDirection(at: positions.0) == .leftToRight ? positions.0 : positions.1

			return textSystem.textRange(from: pos, to: pos)
				.map { Output(selection: $0, delta: 0) }
		}

		guard let pos = textSystem.position(from: positions.0, moving: .left, by: .character) else {
			return nil
		}

		return textSystem.textRange(from: pos, to: pos)
			.map { Output(selection: $0, delta: 0) }
	}

	private func moveRight(
		granularity: TextGranularity,
		textRange: TextRange
	) -> Output? {
		guard let newRange = textSystem.textRange(from: textRange, moving: .right, by: granularity) else {
			return nil
		}

		return Output(selection: newRange, delta: 0)
	}

	private func moveToRightEndOfLine(textRange: TextRange) -> Output? {
		let positions = textSystem.positions(composing: textRange)
		let pos = layoutDirection(at: positions.0) == .leftToRight ? positions.0 : positions.1

		guard
			let newPos = textSystem.position(from: pos, moving: .right, by: .line),
			let newRange = textSystem.textRange(from: newPos, to: newPos)
		else {
			return nil
		}

		return Output(selection: newRange, delta: 0)
	}

	private func moveToLeftEndOfLine(textRange: TextRange) -> Output? {
		let positions = textSystem.positions(composing: textRange)
		let pos = layoutDirection(at: positions.0) == .leftToRight ? positions.0 : positions.1

		guard
			let newPos = textSystem.position(from: pos, moving: .left, by: .line),
			let newRange = textSystem.textRange(from: newPos, to: newPos)
		else {
			return nil
		}

		return Output(selection: newRange, delta: 0)
	}

	private func moveUp(textRange: TextRange, alignment: CGFloat?) -> Output? {
		let positions = textSystem.positions(composing: textRange)
		let pos = layoutDirection(at: positions.0) == .leftToRight ? positions.0 : positions.1

		return textSystem.position(from: pos, moving: .up(alignment: alignment), by: .character)
			.flatMap { textSystem.textRange(from: $0, to: $0) }
			.map { Output(selection: $0, delta: 0) }
	}

	private func moveDown(textRange: TextRange, alignment: CGFloat?) -> Output? {
		let positions = textSystem.positions(composing: textRange)
		let pos = layoutDirection(at: positions.0) == .leftToRight ? positions.0 : positions.1

		return textSystem.position(from: pos, moving: .down(alignment: alignment), by: .character)
			.flatMap { textSystem.textRange(from: $0, to: $0) }
			.map { Output(selection: $0, delta: 0) }
	}
}

extension InputOperationProcessor {
	private func layoutDirection(at position: System.TextPosition) -> TextLayoutDirection {
		textSystem.layoutDirection(at: position) ?? .leftToRight
	}
}
