#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import KeyCodes
import Ligature

@MainActor
public final class MultiCursorState<Tokenizer: TextTokenizer> {
	public typealias Position = Tokenizer.Position
	public typealias TextRange = Tokenizer.TextRange
	public typealias Processor = SelectionProcessor<Tokenizer>

	public var layoutDirection: UserInterfaceLayoutDirection
	public private(set) var cursors: [Cursor<TextRange>]
	public let processor: Processor

	public init(
		cursors: [Cursor<TextRange>] = [],
		layoutDirection: UserInterfaceLayoutDirection = .leftToRight,
		processor: Processor
	) {
        self.cursors = cursors
		self.layoutDirection = layoutDirection
		self.processor = processor
    }

    public var hasMultipleCursors: Bool {
        cursors.isEmpty == false
    }

	public var textRanges: [TextRange] {
		cursors.flatMap { $0.textRanges }
	}

	var tokenizer: Tokenizer {
		processor.tokenizer
	}

	private func sortCursors() {
		self.cursors.sort { a, b in
			let aFirst = a.textRanges.first
			let bFirst = b.textRanges.first

			return processor.positionComparator(aFirst!.lowerBound, bFirst!.lowerBound)
		}
	}
}

extension MultiCursorState where TextRange == Range<Int> {
	public convenience init(
		cursors: [Cursor<TextRange>] = [],
		layoutDirection: UserInterfaceLayoutDirection = .leftToRight,
		tokenizer: Tokenizer
	) {
		self.init(
			cursors: cursors,
			layoutDirection: layoutDirection,
			processor: SelectionProcessor(tokenizer: tokenizer)
		)
	}
}

extension MultiCursorState {
    public func addCursorAbove() {

	}

	public func addCursorBelow() {
		guard let cursor = cursors.last else {
			assertionFailure("must have at least one cursor")
			return
		}

		let newRanges = cursor.textRanges.compactMap { processor.moveDown($0) }

		cursors.append(Cursor(textRanges: newRanges))

	}

	public func addCursor(at position: Position) {
		guard let range = processor.rangeBuilder(position, position) else {
			return
		}

		let newCursor = Cursor(textRange: range)

		// insertion would be more efficient
		self.cursors.append(newCursor)
		sortCursors()
	}
}

extension MultiCursorState {
#if os(macOS)
    /// Process a keyDown event
    ///
    /// - Returns: true if the event was processed and should now be ignored.
	public func handleKeyDown(with event: NSEvent) -> Bool {
		let flags = event.keyModifierFlags?.subtracting(.numericPad) ?? []
		let key = event.keyboardHIDUsage

		switch (flags, key) {
		case ([.control, .shift], .keyboardUpArrow):
			addCursorAbove()
            return true
		case ([.control, .shift], .keyboardDownArrow):
			addCursorBelow()
            return true
		case ([], .keyboardLeftArrow):
			moveLeft()
			return true
		default:
			break
		}

		return false
	}
#endif
}

// MARK: Responder functions
extension MultiCursorState {
	private func updateCursorRanges(in direction: TextDirection) {
		self.cursors = cursors.compactMap { cursor in
			var newCursor = cursor

			newCursor.textRanges = cursor.textRanges.compactMap { processor.range(from: $0, to: .character, in: direction) }

			return newCursor
		}
	}

	public func moveLeft() {
		updateCursorRanges(in: .layout(.left))
	}

	public func moveRight() {
		updateCursorRanges(in: .layout(.right))
	}
}
