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
	case insertText(String)
	case insertAttributedString(AttributedString)
	case insertTextArray([String])
	case moveToLeftEndOfLine(selecting: Bool = false)
	case moveToRightEndOfLine(selecting: Bool = false)
	case moveToEndOfDocument(selecting: Bool = false)

	func indexedOperation(for cursorIndex: Int) -> InputOperation {
		switch self {
		case let .insertTextArray(array):
			.insertText(array[cursorIndex])
		default:
			self
		}
	}

#if os(macOS)
	public init?(selector: Selector, lineEnding: String = "\n") {
		switch selector {
		case #selector(NSResponder.deleteBackward(_:)):
			self = .deleteBackwards(.character)
		case #selector(NSResponder.deleteToBeginningOfLine(_:)):
			self = .deleteBackwards(.line)
		case #selector(NSResponder.deleteWordBackward(_:)):
			self = .deleteBackwards(.word)
		case #selector(NSResponder.moveLeft(_:)):
			self = .moveLeft(.character)
		case #selector(NSResponder.moveWordLeft(_:)):
			self = .moveLeft(.word, selecting: false)
		case #selector(NSResponder.moveWordLeftAndModifySelection(_:)):
			self = .moveLeft(.word, selecting: true)
		case #selector(NSResponder.moveWordRight(_:)):
			self = .moveRight(.word, selecting: false)
		case #selector(NSResponder.moveWordRightAndModifySelection(_:)):
			self = .moveRight(.word, selecting: true)
		case #selector(NSResponder.moveLeftAndModifySelection(_:)):
			self = .moveLeft(.character, selecting: true)
		case #selector(NSResponder.moveToLeftEndOfLine(_:)):
			self = .moveToLeftEndOfLine(selecting: false)
		case #selector(NSResponder.moveRight(_:)):
			self = .moveRight(.character)
		case #selector(NSResponder.moveRightAndModifySelection(_:)):
			self = .moveRight(.character, selecting: true)
		case #selector(NSResponder.moveToRightEndOfLine(_:)):
			self = .moveToRightEndOfLine(selecting: false)
		case #selector(NSResponder.moveDown(_:)):
			self = .moveDown
		case #selector(NSResponder.moveUp(_:)):
			self = .moveUp
		case #selector(NSResponder.insertNewline(_:)):
			self = .insertText(lineEnding)
		case #selector(NSResponder.moveToEndOfDocument(_:)):
			self = .moveToEndOfDocument(selecting: false)
		default:
			if NSResponder.selectorsAffectingCursor.contains(selector) {
				print("WARNING: Unhandled cursor mutation \(selector). This could result in state corruption.")
			}

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

	public var affectsContent: Bool {
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
