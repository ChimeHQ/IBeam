#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum InputOperation {
	case deleteBackwards(TextGranularity)
	case moveLeft(TextGranularity)
	case moveRight(TextGranularity)
	case moveUp
	case moveDown
	case insertText(AttributedString)
	case moveToLeftEndOfLine
	case moveToRightEndOfLine

	public static func insertText(_ value: String) -> InputOperation {
		Self.insertText(AttributedString(value))
	}

#if os(macOS)
	public init?(selector: Selector) {
		switch selector {
		case #selector(NSResponder.moveLeft(_:)):
			self = .moveLeft(.character)
		case #selector(NSResponder.moveRight(_:)):
			self = .moveRight(.character)
		case #selector(NSResponder.moveDown(_:)):
			self = .moveDown
		case #selector(NSResponder.moveUp(_:)):
			self = .moveUp
		case #selector(NSResponder.deleteBackward(_:)):
			self = .deleteBackwards(.character)
		case #selector(NSResponder.moveToLeftEndOfLine(_:)):
			self = .moveToLeftEndOfLine
		case #selector(NSResponder.moveToRightEndOfLine(_:)):
			self = .moveToRightEndOfLine
		default:
			return nil
		}
	}
#endif

	public var affectsAlignment: Bool {
		switch self {
		case .moveUp, .moveDown:
			return false
		default:
			return true
		}
	}
}
