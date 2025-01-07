import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSMutableAttributedString {
	/// Compute and register the inverse mutation required to undo replacing the content within `range`.
	public func registerMutationUndo(
		with undoManager: UndoManager?,
		range: NSRange,
		delta: Int
	) {
		guard let undoManager else {
			return
		}

		// while this is technically cheating, I believe it to be safe
		nonisolated(unsafe) let existingString = attributedSubstring(from: range)
		let newLength = existingString.length + max(delta, 0)

		precondition(newLength > 0)

		let inverseRange = NSRange(location: range.location, length: newLength)

		undoManager.registerUndo(withTarget: self, handler: { target in
			target.replaceCharacters(in: inverseRange, with: existingString)
		})
	}
}

/// Implements a large portion of the T`extSystemInterface` protocol for `NSMutableAttributedString`-compatible backing stores.
public struct MutableStringPartialInterface {
	private let content: NSMutableAttributedString

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

extension MutableStringPartialInterface {
	public func position(from start: Int, offset: Int) -> Int? {
		start + offset
	}

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

	// range calculation
	public var beginningOfDocument: Int {
		return 0
	}

	public var endOfDocument: Int {
		return content.length
	}

	public func compare(_ position: Int, to other: Int) -> ComparisonResult {
		if position < other {
			return .orderedAscending
		}

		if position > other {
			return .orderedDescending
		}

		return .orderedSame
	}

	public func positions(composing range: NSRange) -> (Int, Int) {
		(range.lowerBound, range.upperBound)
	}

	public func textRange(from start: Int, to end: Int) -> NSRange? {
		NSRange(start..<end)
	}

	// content mutation
	public func beginEditing() {
		content.beginEditing()
	}

	public func endEditing() {
		content.endEditing()
	}

	public func applyMutation(_ range: NSRange, string: NSAttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange>? {
		let length = string.length

		content.registerMutationUndo(with: undoManager, range: range, delta: length - range.length)

		content.replaceCharacters(in: range, with: string)

		let delta = length - range.length
		let position = min(range.lowerBound + length, content.length)

		let newSelection = NSRange(position..<position)

		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
	}

	public func applyMutation(_ range: NSRange, string: AttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange>? {
		let nsAttrString = NSAttributedString(string)

		return applyMutation(range, string: nsAttrString, undoManager: undoManager)
	}
}
