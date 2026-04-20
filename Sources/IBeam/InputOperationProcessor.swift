import Foundation

import Rearrange

extension CalculatedRange where Calculator : TextSystemInterface {
	func bound(for direction: TextDirection) -> Position? {
		return switch direction {
		case .backward:
			range.lowerBound
		case .forward:
			range.upperBound
		case .left:
			calculator.layoutDirection(at: range.lowerBound) == .rightToLeft ? range.upperBound : range.lowerBound
		case .right:
			calculator.layoutDirection(at: range.lowerBound) == .rightToLeft ? range.lowerBound : range.upperBound
		case .down, .up:
			nil
		}
	}
}

struct InputOperationProcessor<System: TextSystemInterface> {
	typealias CursorState = MultiCursorState<System>
	typealias TextRange = CalculatedRange<System>
	typealias TextPosition = System.TextRange.Bound
	typealias Output = MutationOutput<System.TextRange>

	let textSystem: System

	public var fullRange: System.TextRange {
		textSystem.fullDocumentRange
	}

	private func layoutDirection(at position: TextPosition) -> TextLayoutDirection {
		textSystem.layoutDirection(at: position) ?? .leftToRight
	}

	public func apply(_ operation: InputOperation, to cursor: Cursor<System.TextRange>, delta: Int) -> Output? {
		// step one, apply delta
		let range = CalculatedRange(cursor.textRange, calculator: textSystem).offset(by: delta)

		guard let range else { return nil }

		let affinity = cursor.affinity

		switch operation {
		case let .insertText(value):
			let mutation = TextMutation<System.TextRange>(
				range: range.range,
				string: value,
				cursorId: cursor.id,
				offset: delta
			)

			return try! textSystem.applyMutation(mutation)
		case .insertAttributedString:
			fatalError("this isn't supported yet")
		case let .deleteBackwards(value):
			return deleteBackwards(granularity: value, textRange: range, cursorId: cursor.id, offset: delta)
		case let .moveLeft(granularity, selecting):
			return moveLeft(
				granularity: granularity,
				selecting: selecting,
				affinity: affinity,
				textRange: range
			)
		case let .moveRight(granularity, selecting):
			return moveRight(
				granularity: granularity,
				selecting: selecting,
				affinity: affinity,
				textRange: range
			)
		case .moveUp:
			return moveUp(textRange: range, alignment: cursor.alignment)
		case .moveDown:
			return moveDown(textRange: range, alignment: cursor.alignment)
		case .moveToRightEndOfLine:
			return moveToRightEndOfLine(textRange: range)
		case .moveToLeftEndOfLine:
			return moveToLeftEndOfLine(textRange: range)
		case .moveToEndOfDocument(selecting: let selecting):
			return moveToEndOfDocument(selecting: selecting, textRange: range)
		case .insertTextArray:
			fatalError("This operation cannot be processed on a per-cursor basis")
		}
	}

	private func deleteBackwards(granularity: TextGranularity, textRange: CalculatedRange<System>, cursorId: UUID, offset: Int) -> Output? {
		let emptyString = String()

		if textRange.isEmpty {
			guard
				let newLower = textSystem.position(from: textRange.range.lowerBound, moving: .backward, by: granularity),
				let deleteRange = textSystem.textRange(from: newLower, to: textRange.range.lowerBound)
			else {
				return nil
			}

			return try! textSystem.applyMutation(deleteRange, string: emptyString, cursorId: cursorId, offset: offset)
		}

		return try! textSystem.applyMutation(textRange.range, string: emptyString, cursorId: cursorId, offset: offset)
	}

	private func moveLeft(
		granularity: TextGranularity,
		selecting: Bool,
		affinity: SelectionAffinity?,
		textRange: TextRange
	) -> Output? {
		switch (affinity, selecting) {
		case (_, false):
			// if the range is empty, we can just shift either bound and be done
			if textRange.isEmpty {
				guard let pos = textSystem.position(from: textRange.range.lowerBound, moving: .left, by: granularity) else {
					return nil
				}

				return textSystem
					.textRange(from: pos, to: pos)
					.map { Output(selection: $0, delta: 0) }
			}

			// non-empty, so we have to choose one edge and make tha the new selection
			guard let pos = textRange.bound(for: .left) else {
				return nil
			}

			return textSystem
				.textRange(from: pos, to: pos)
				.map { Output(selection: $0, delta: 0) }
		case (nil, true):
			let rtl = textSystem.layoutDirection(at: textRange.range.lowerBound) == .rightToLeft

			let leftmost = rtl ? textRange.range.upperBound : textRange.range.lowerBound

			guard let pos = textSystem.position(from: leftmost, moving: .left, by: granularity) else {
				return nil
			}

			// we now need to re-create a range, but have to first figure out which position is which
			let start = rtl ? textRange.range.lowerBound : pos
			let end = rtl ? pos : textRange.range.upperBound

			return textSystem
				.textRange(from: start, to: end)
				.map { Output(selection: $0, delta: 0, affinity: rtl ? .upstream : .downstream) }
		case (.upstream?, true):
			guard let pos = textSystem.position(from: textRange.range.lowerBound, moving: .left, by: granularity) else {
				return nil
			}

			if textSystem.compare(pos, to: textRange.range.upperBound) == .orderedAscending {
				return textSystem
					.textRange(from: pos, to: textRange.range.upperBound)
					.map { Output(selection: $0, delta: 0, affinity: .upstream) }
			}

			return textSystem
				.textRange(from: textRange.range.upperBound, to: pos)
				.map { Output(selection: $0, delta: 0, affinity: .downstream) }
		case (.downstream?, true):
			guard let pos = textSystem.position(from: textRange.range.upperBound, moving: .left, by: granularity) else {
				return nil
			}

			if textSystem.compare(textRange.range.lowerBound, to: pos) == .orderedAscending {
				return textSystem
					.textRange(from: textRange.range.lowerBound, to: pos)
					.map { Output(selection: $0, delta: 0, affinity: .downstream) }
			}

			return textSystem
				.textRange(from: pos, to: textRange.range.lowerBound)
				.map { Output(selection: $0, delta: 0, affinity: .upstream) }
		}
	}

	private func moveRight(
		granularity: TextGranularity,
		selecting: Bool,
		affinity: SelectionAffinity?,
		textRange: TextRange
	) -> Output? {
		switch (affinity, selecting) {
		case (_, false):
			// if the range is empty, we can just shift either bound and be done
			if textRange.isEmpty {
				guard let pos = textSystem.position(from: textRange.range.lowerBound, moving: .right, by: granularity) else {
					return nil
				}

				return textSystem
					.textRange(from: pos, to: pos)
					.map { Output(selection: $0, delta: 0) }
			}

			// non-empty, so we have to choose one edge and make tha the new selection
			guard let pos = textRange.bound(for: .right) else {
				return nil
			}

			return textSystem
				.textRange(from: pos, to: pos)
				.map { Output(selection: $0, delta: 0) }
		case (nil, true):
			let rtl = textSystem.layoutDirection(at: textRange.range.lowerBound) == .rightToLeft

			let rightmost = rtl ? textRange.range.lowerBound : textRange.range.upperBound

			guard let pos = textSystem.position(from: rightmost, moving: .right, by: granularity) else {
				return nil
			}

			// we now need to re-create a range, but have to first figure out which position is which
			let start = rtl ? pos : textRange.range.lowerBound
			let end = rtl ? textRange.range.upperBound : pos

			return textSystem
				.textRange(from: start, to: end)
				.map { Output(selection: $0, delta: 0, affinity: rtl ? .upstream : .downstream) }
		case (.upstream?, true):
			guard let pos = textSystem.position(from: textRange.range.lowerBound, moving: .right, by: granularity) else {
				return nil
			}

			if textSystem.compare(pos, to: textRange.range.upperBound) == .orderedAscending {
				return textSystem
					.textRange(from: pos, to: textRange.range.upperBound)
					.map { Output(selection: $0, delta: 0, affinity: .upstream) }
			}

			return textSystem
				.textRange(from: textRange.range.upperBound, to: pos)
				.map { Output(selection: $0, delta: 0, affinity: .downstream) }
		case (.downstream?, true):
			guard let pos = textSystem.position(from: textRange.range.upperBound, moving: .right, by: granularity) else {
				return nil
			}

			if textSystem.compare(textRange.range.lowerBound, to: pos) == .orderedAscending {
				return textSystem
					.textRange(from: textRange.range.lowerBound, to: pos)
					.map { Output(selection: $0, delta: 0, affinity: .downstream) }
			}

			return textSystem
				.textRange(from: pos, to: textRange.range.lowerBound)
				.map { Output(selection: $0, delta: 0, affinity: .upstream) }
		}
	}

	private func moveToRightEndOfLine(textRange: TextRange) -> Output? {
		let pos = layoutDirection(at: textRange.range.lowerBound) == .leftToRight ? textRange.range.lowerBound : textRange.range.upperBound

		guard
			let newPos = textSystem.position(from: pos, moving: .right, by: .line),
			let newRange = textSystem.textRange(from: newPos, to: newPos)
		else {
			return nil
		}

		return Output(selection: newRange, delta: 0)
	}

	private func moveToLeftEndOfLine(textRange: TextRange) -> Output? {
		let pos = layoutDirection(at: textRange.range.lowerBound) == .leftToRight ? textRange.range.lowerBound : textRange.range.upperBound

		guard
			let newPos = textSystem.position(from: pos, moving: .left, by: .line),
			let newRange = textSystem.textRange(from: newPos, to: newPos)
		else {
			return nil
		}

		return Output(selection: newRange, delta: 0)
	}

	private func moveUp(textRange: TextRange, alignment: CGFloat?) -> Output? {
		let pos = layoutDirection(at: textRange.range.lowerBound) == .leftToRight ? textRange.range.lowerBound : textRange.range.upperBound

		return textSystem.position(from: pos, moving: .up(alignment: alignment), by: .character)
			.flatMap { textSystem.textRange(from: $0, to: $0) }
			.map { Output(selection: $0, delta: 0) }
	}

	private func moveDown(textRange: TextRange, alignment: CGFloat?) -> Output? {
		let pos = layoutDirection(at: textRange.range.lowerBound) == .leftToRight ? textRange.range.lowerBound : textRange.range.upperBound

		return textSystem.position(from: pos, moving: .down(alignment: alignment), by: .character)
			.flatMap { textSystem.textRange(from: $0, to: $0) }
			.map { Output(selection: $0, delta: 0) }
	}

	private func moveToEndOfDocument(
		selecting: Bool,
		textRange: TextRange
	) -> Output? {
		let end = textSystem.endOfDocument

		return textSystem.textRange(from: end, to: end)
			.map { Output(selection: $0, delta: 0) }
	}
}
