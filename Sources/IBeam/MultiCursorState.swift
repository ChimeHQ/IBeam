#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import KeyCodes
import Ligature

public enum SelectionAffinity: Hashable, Sendable, Codable {
	case upstream
	case downstream
}

@MainActor
public final class MultiCursorState<Tokenizer: TextTokenizer> where Tokenizer.Position: Comparable {
	public typealias Position = Tokenizer.Position
	public typealias Cursor = IBeam.Cursor<Position>

	public var affinity: SelectionAffinity
    public var cursors: [Cursor]
	public let tokenizer: Tokenizer

	public init(cursors: [Cursor] = [], affinity: SelectionAffinity = .upstream, tokenizer: Tokenizer) {
        self.cursors = cursors
		self.affinity = affinity
		self.tokenizer = tokenizer
    }

    public var hasMultipleCursors: Bool {
        cursors.isEmpty == false
    }
}

extension MultiCursorState {
    public func addCursorAbove() {

	}

	public func addCursorBelow() {
		guard let range = cursors.last?.range else {
			assertionFailure("at least one cursor should be present")
			return
		}

		guard
			let start = tokenizer.position(from: range.lowerBound, toBoundary: .character, inDirection: .layout(.down)),
			let end = tokenizer.position(from: range.upperBound, toBoundary: .character, inDirection: .layout(.down))
		else {
			return
		}

		let newCursor = Cursor(range: start..<end)

		self.cursors.append(newCursor)
		self.cursors.sort()
	}

	public func addCursor(at position: Position) {
		let newCursor = Cursor(range: position..<position)

		self.cursors.append(newCursor)
		self.cursors.sort()
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
			moveLeft(self)
			return true
		default:
			break
		}

		return false
	}
#endif
}

extension MultiCursorState {
	public func moveLeft(_ sender: Any?) {
		self.cursors = cursors.compactMap { cursor in
			let start = cursor.range.lowerBound
			guard let newStart = tokenizer.position(from: start, toBoundary: .character, inDirection: .layout(.left)) else {
				return nil
			}

			var cursor = cursor

			switch affinity {
			case .upstream:
				cursor.range = newStart..<newStart
			case .downstream:
				cursor.range = newStart..<cursor.range.upperBound
			}

			return cursor
		}
	}
}
