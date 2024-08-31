#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import KeyCodes

public enum SelectionAffinity: Hashable, Sendable, Codable {
	case upstream
	case downstream
}

public struct MultiCursorState<CoordinateProvider: TextCoordinateProvider> {
	public typealias TextLocation = CoordinateProvider.TextLocation
	public typealias Cursor = IBeam.Cursor<TextLocation>

	public var affinity: SelectionAffinity
    public var cursors: [Cursor]
	public let coordinateProvider: CoordinateProvider

	public init(cursors: [Cursor] = [], affinity: SelectionAffinity = .upstream, coordinateProvider: CoordinateProvider) {
        self.cursors = cursors
		self.affinity = affinity
		self.coordinateProvider = coordinateProvider
    }

    public var hasMultipleCursors: Bool {
        cursors.isEmpty == false
    }
}

extension MultiCursorState {
    public func addCursorAbove() {

	}

	public mutating func addCursorBelow() {
		guard let range = cursors.last?.range else {
			assertionFailure("at least one cursor should be present")
			return
		}

		guard
			let start = coordinateProvider.closestMatchingVerticalLocation(to: range.lowerBound, above: false),
			let end = coordinateProvider.closestMatchingVerticalLocation(to: range.upperBound, above: false)
		else {
			return
		}

		let newCursor = Cursor(range: start..<end)

		self.cursors.append(newCursor)
		self.cursors.sort()
	}

	public mutating func addCursor(at location: TextLocation) {
		let newCursor = Cursor(range: location..<location)

		self.cursors.append(newCursor)
		self.cursors.sort()
	}
}

extension MultiCursorState {
    /// Process a keyDown event
    ///
    /// - Returns: true if the event was processed and should now be ignored.
	public mutating func handleKeyDown(with event: NSEvent) -> Bool {
		let flags = event.keyModifierFlags?.subtracting(.numericPad) ?? []
		let key = event.keyboardHIDUsage

		switch (flags, key) {
		case ([.control, .shift], .keyboardUpArrow):
			addCursorAbove()
            return true
		case ([.control, .shift], .keyboardDownArrow):
			addCursorBelow()
            return true
		default:
			break
		}

        guard hasMultipleCursors else {
            return false
        }

		return false
	}
}
