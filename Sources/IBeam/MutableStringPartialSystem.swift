import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Rearrange

//extension NSMutableAttributedString {
//	/// Compute and register the inverse mutation required to undo replacing the content within `range`.
//	public func registerMutationUndo(
//		with undoManager: UndoManager?,
//		range: NSRange,
//		delta: Int
//	) {
//		guard let undoManager else {
//			return
//		}
//
//		// while this is technically cheating, I believe it to be safe
//		nonisolated(unsafe) let existingString = attributedSubstring(from: range)
//		let newLength = existingString.length + max(delta, 0)
//
//		precondition(newLength > 0)
//
//		let inverseRange = NSRange(location: range.location, length: newLength)
//
//		undoManager.registerUndo(withTarget: self, handler: { target in
//			target.replaceCharacters(in: inverseRange, with: existingString)
//		})
//	}
//}

/// Implements a large portion of the T`extSystemInterface` protocol for `NSMutableAttributedString`-compatible backing stores.
public final class MutableStringPartialInterface {
	private let content: NSMutableAttributedString
	public var willApplyMutation: ((TextRange, NSAttributedString) -> Void)?

	public init(_ content: NSMutableAttributedString) {
		self.content = content
	}

	public var attributedString: NSAttributedString {
		content
	}

	public var string: String {
		content.string
	}
}

extension MutableStringPartialInterface : TextRangeCalculating {
	public typealias TextRange = NSRange

	public var beginningOfDocument: Int {
		0
	}

	public var endOfDocument: Int {
		content.length
	}

	public func textRange(from start: Position, to end: Position) -> NSRange? {
		NSRange(start..<end)
	}
}

extension MutableStringPartialInterface {
	public func layoutDirection(at position: Int) -> TextLayoutDirection? {
		if position >= content.length {
			return nil
		}

		let attrs = content.attributes(at: position, effectiveRange: nil)
		guard let direction = attrs[.writingDirection] as? NSNumber else {
			return nil
		}

		return switch direction.intValue {
		case NSWritingDirection.leftToRight.rawValue:
			.leftToRight
		case NSWritingDirection.rightToLeft.rawValue:
			.rightToLeft
		default:
			nil
		}
	}

	// content mutation
	public func beginEditing() {
		content.beginEditing()
	}

	public func endEditing() {
		content.endEditing()
	}

	public func applyMutation(_ range: NSRange, string: NSAttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange>? {
		let plainString = string.string
		let length = plainString.utf16.count
		let delta = length - range.length

		willApplyMutation?(range, string)

		if let undoManager {
			nonisolated(unsafe) let existingString = content.attributedSubstring(from: range)
			nonisolated(unsafe) let capturedUndoManager = undoManager

			let inverseRange = NSRange(
				location: range.location,
				length: range.length + delta
			)

			undoManager.registerUndo(withTarget: self) { target in
				_ = target.applyMutation(inverseRange, string: existingString, undoManager: capturedUndoManager)
			}
		}

		content.replaceCharacters(in: range, with: string)

		let position = min(range.lowerBound + length, content.length)

		let newSelection = NSRange(position..<position)

		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
	}

	public func applyMutation(_ range: NSRange, string: AttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange>? {
		let nsAttrString = NSAttributedString(string)

		return applyMutation(range, string: nsAttrString, undoManager: undoManager)
	}
}
