import Foundation

extension NSAttributedString {
	public func layoutDirection(at position: Int) -> TextLayoutDirection? {
		if position >= length {
			return nil
		}

		let attrs = attributes(at: position, effectiveRange: nil)
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
}

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Rearrange

/// Implements a large portion of the `TextSystemInterface` protocol for `NSMutableAttributedString`-compatible backing stores.
public final class MutableStringPartialInterface {
	private let content: NSMutableAttributedString
	public var willBeginEditing: (() -> Void)?
	public var didEndEditing: (() -> Void)?
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

	public var endOfDocument: Int {
		content.length
	}
}

extension MutableStringPartialInterface {
	public func layoutDirection(at position: Int) -> TextLayoutDirection? {
		content.layoutDirection(at: position)
	}

	// content mutation
	public func beginEditing() {
		willBeginEditing?()
		content.beginEditing()
	}

	public func endEditing() {
		content.endEditing()
		didEndEditing?()
	}

	@MainActor
	public func applyMutation(_ range: NSRange, string: NSAttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange> {
		let plainString = string.string
		let length = plainString.utf16.count
		let delta = length - range.length

		willApplyMutation?(range, string)

		if let undoManager {
			let existingString = content.attributedSubstring(from: range)

			let inverseRange = NSRange(
				location: range.location,
				length: range.length + delta
			)

			undoManager.registerUndo(withTarget: self) { [weak undoManager] target in
				_ = target.applyMutation(inverseRange, string: existingString, undoManager: undoManager)
			}
		}

		content.replaceCharacters(in: range, with: string)

		let position = min(range.lowerBound + length, content.length)

		let newSelection = NSRange(position..<position)

		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
	}

	@MainActor
	public func applyMutation(_ mutation: TextMutation<NSRange>, undoManager: UndoManager?) -> MutationOutput<NSRange> {
		let nsAttrString = NSAttributedString(mutation.string)

		return applyMutation(mutation.range, string: nsAttrString, undoManager: undoManager)
	}
}
