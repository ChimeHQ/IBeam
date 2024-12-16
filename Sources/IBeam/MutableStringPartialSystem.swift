import Foundation

import AppKit

/// Implements a large portion of the TextSystem protocol for NSMutableAttributedString-compatible backing stores.
public struct MutableStringPartialSystem {
	private var content: NSMutableAttributedString
	
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

extension MutableStringPartialSystem {
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

//	public func applyMutation(_ range: NSRange, string: AttributedString) -> MutationOutput<NSRange>? {
//		let nsAttrString = NSAttributedString(string)
//		let length = nsAttrString.length
//
//		content.replaceCharacters(in: range, with: nsAttrString)
//
//		let delta = length - range.length
//		let position = min(range.lowerBound + length, content.length)
//
//		let newSelection = NSRange(position..<position)
//
//		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
//	}

	public func applyMutation(in range: NSRange, string: AttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange> {
		let nsAttrString = NSAttributedString(string)
		let length = nsAttrString.length

		let existingString = AttributedString(content.attributedSubstring(from: range))

		undoManager?.registerMainActorUndo(withTarget: content, handler: { target in
			let existingNSAttrString = NSAttributedString(existingString)

			target.replaceCharacters(in: range, with: existingNSAttrString)
		})

		content.replaceCharacters(in: range, with: nsAttrString)

		let delta = length - range.length
		let position = min(range.lowerBound + length, content.length)

		let newSelection = NSRange(position..<position)

		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
	}
}
