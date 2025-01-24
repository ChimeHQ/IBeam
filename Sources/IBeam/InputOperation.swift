#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum InputOperation {
	case deleteBackwards(TextGranularity)
	case moveLeft(TextGranularity, selecting: Bool = false)
	case moveRight(TextGranularity, selecting: Bool = false)
	case moveUp
	case moveDown
	case insertText(AttributedString)
	case insertTextArray([AttributedString])
	case moveToLeftEndOfLine(selecting: Bool = false)
	case moveToRightEndOfLine(selecting: Bool = false)

	public static func insertText(_ value: String) -> InputOperation {
		Self.insertText(AttributedString(value))
	}

	public static func insertTextArray(_ value: [String]) -> InputOperation {
		Self.insertTextArray(value.map { AttributedString($0) })
	}

	func indexedOperation(for cursorIndex: Int) -> InputOperation {
		switch self {
		case let .insertTextArray(array):
			.insertText(array[cursorIndex])
		default:
			self
		}
	}

#if os(macOS)
	public init?(selector: Selector) {
		switch selector {
		case #selector(NSResponder.moveLeft(_:)):
			self = .moveLeft(.character)
		case #selector(NSResponder.moveLeftAndModifySelection(_:)):
			self = .moveLeft(.character, selecting: true)
		case #selector(NSResponder.moveRight(_:)):
			self = .moveRight(.character)
		case #selector(NSResponder.moveRightAndModifySelection(_:)):
			self = .moveRight(.character, selecting: true)
		case #selector(NSResponder.moveDown(_:)):
			self = .moveDown
		case #selector(NSResponder.moveUp(_:)):
			self = .moveUp
		case #selector(NSResponder.deleteBackward(_:)):
			self = .deleteBackwards(.character)
		case #selector(NSResponder.moveToLeftEndOfLine(_:)):
			self = .moveToLeftEndOfLine(selecting: false)
		case #selector(NSResponder.moveToRightEndOfLine(_:)):
			self = .moveToRightEndOfLine(selecting: false)
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

	public var supportsUndo: Bool {
		switch self {
		case .deleteBackwards:
			true
		case .insertText, .insertTextArray:
			true
		default:
			false
		}
	}
}
