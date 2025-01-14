import Foundation

// Is this helpful? I *think* so...
struct InterfaceRange<Interface: TextSystemInterface> {
	enum BoundSelector {
		case upstream
		case downstream
		case left
		case right
	}

	let lowerBound: Interface.TextPosition
	let upperBound: Interface.TextPosition
	let interface: Interface

	init(_ textRange: Interface.TextRange, interface: Interface) {
		self.interface = interface

		(self.lowerBound, self.upperBound) = interface.positions(composing: textRange)
	}

	var textRange: Interface.TextRange? {
		interface.textRange(from: lowerBound, to: upperBound)
	}

	var isEmpty: Bool {
		interface.compare(lowerBound, to: upperBound) == .orderedSame
	}

	func bound(for direction: TextDirection) -> Interface.TextPosition? {
		return switch direction {
		case .backward:
			lowerBound
		case .forward:
			upperBound
		case .left:
			interface.layoutDirection(at: lowerBound) == .rightToLeft ? upperBound : lowerBound
		case .right:
			interface.layoutDirection(at: lowerBound) == .rightToLeft ? lowerBound : upperBound
		case .down, .up:
			nil
		}
	}
}

struct InputOperationProcessor<System: TextSystemInterface> {
	typealias CursorState = MultiCursorState<System>
	typealias TextRange = System.TextRange
	typealias TextPosition = System.TextPosition
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

		let affinity = cursor.affinity

		switch operation {
		case let .insertText(value):
			return textSystem.applyMutation(textRange, string: value)
		case let .deleteBackwards(value):
			return deleteBackwards(granularity: value, textRange: textRange)
		case let .moveLeft(granularity, selecting):
			return moveLeft(
				granularity: granularity,
				selecting: selecting,
				affinity: affinity,
				textRange: textRange
			)
		case let .moveRight(granularity, selecting):
			return moveRight(
				granularity: granularity,
				selecting: selecting,
				affinity: affinity,
				textRange: textRange
			)
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
		selecting: Bool,
		affinity: SelectionAffinity?,
		textRange: TextRange
	) -> Output? {
		let range = InterfaceRange(textRange, interface: textSystem)

		switch (affinity, selecting) {
		case (_, false):
			// if the range is empty, we can just shift either bound and be done
			if range.isEmpty {
				guard let pos = textSystem.position(from: range.lowerBound, moving: .left, by: granularity) else {
					return nil
				}

				return textSystem
					.textRange(from: pos, to: pos)
					.map { Output(selection: $0, delta: 0) }
			}

			// non-empty, so we have to choose one edge and make tha the new selection
			guard let pos = range.bound(for: .left) else {
				return nil
			}

			return textSystem
				.textRange(from: pos, to: pos)
				.map { Output(selection: $0, delta: 0) }
		case (nil, true):
			let rtl = textSystem.layoutDirection(at: range.lowerBound) == .rightToLeft

			let leftmost = rtl ? range.upperBound : range.lowerBound

			guard let pos = textSystem.position(from: leftmost, moving: .left, by: granularity) else {
				return nil
			}

			// we now need to re-create a range, but have to first figure out which position is which
			let start = rtl ? range.lowerBound : pos
			let end = rtl ? pos : range.upperBound

			return textSystem
				.textRange(from: start, to: end)
				.map { Output(selection: $0, delta: 0, affinity: rtl ? .upstream : .downstream) }
		case (.upstream?, true):
			guard let pos = textSystem.position(from: range.lowerBound, moving: .left, by: granularity) else {
				return nil
			}

			if textSystem.compare(pos, to: range.upperBound) == .orderedAscending {
				return textSystem
					.textRange(from: pos, to: range.upperBound)
					.map { Output(selection: $0, delta: 0, affinity: .upstream) }
			}

			return textSystem
				.textRange(from: range.upperBound, to: pos)
				.map { Output(selection: $0, delta: 0, affinity: .downstream) }
		case (.downstream?, true):
			guard let pos = textSystem.position(from: range.upperBound, moving: .left, by: granularity) else {
				return nil
			}

			if textSystem.compare(range.lowerBound, to: pos) == .orderedAscending {
				return textSystem
					.textRange(from: range.lowerBound, to: pos)
					.map { Output(selection: $0, delta: 0, affinity: .downstream) }
			}

			return textSystem
				.textRange(from: pos, to: range.lowerBound)
				.map { Output(selection: $0, delta: 0, affinity: .upstream) }
		}
	}

	private func moveRight(
		granularity: TextGranularity,
		selecting: Bool,
		affinity: SelectionAffinity?,
		textRange: TextRange
	) -> Output? {
		let range = InterfaceRange(textRange, interface: textSystem)

		switch (affinity, selecting) {
		case (_, false):
			// if the range is empty, we can just shift either bound and be done
			if range.isEmpty {
				guard let pos = textSystem.position(from: range.lowerBound, moving: .right, by: granularity) else {
					return nil
				}

				return textSystem
					.textRange(from: pos, to: pos)
					.map { Output(selection: $0, delta: 0) }
			}

			// non-empty, so we have to choose one edge and make tha the new selection
			guard let pos = range.bound(for: .right) else {
				return nil
			}

			return textSystem
				.textRange(from: pos, to: pos)
				.map { Output(selection: $0, delta: 0) }
		case (nil, true):
			let rtl = textSystem.layoutDirection(at: range.lowerBound) == .rightToLeft

			let rightmost = rtl ? range.lowerBound : range.upperBound

			guard let pos = textSystem.position(from: rightmost, moving: .right, by: granularity) else {
				return nil
			}

			// we now need to re-create a range, but have to first figure out which position is which
			let start = rtl ? pos : range.lowerBound
			let end = rtl ? range.upperBound : pos

			return textSystem
				.textRange(from: start, to: end)
				.map { Output(selection: $0, delta: 0, affinity: rtl ? .upstream : .downstream) }
		case (.upstream?, true):
			guard let pos = textSystem.position(from: range.lowerBound, moving: .right, by: granularity) else {
				return nil
			}

			if textSystem.compare(pos, to: range.upperBound) == .orderedAscending {
				return textSystem
					.textRange(from: pos, to: range.upperBound)
					.map { Output(selection: $0, delta: 0, affinity: .upstream) }
			}

			return textSystem
				.textRange(from: range.upperBound, to: pos)
				.map { Output(selection: $0, delta: 0, affinity: .downstream) }
		case (.downstream?, true):
			guard let pos = textSystem.position(from: range.upperBound, moving: .right, by: granularity) else {
				return nil
			}

			if textSystem.compare(range.lowerBound, to: pos) == .orderedAscending {
				return textSystem
					.textRange(from: range.lowerBound, to: pos)
					.map { Output(selection: $0, delta: 0, affinity: .downstream) }
			}

			return textSystem
				.textRange(from: pos, to: range.lowerBound)
				.map { Output(selection: $0, delta: 0, affinity: .upstream) }
		}
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
