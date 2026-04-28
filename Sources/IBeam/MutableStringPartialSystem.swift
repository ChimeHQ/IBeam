#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import Rearrange

/// Implements a large portion of the `TextSystemInterface` protocol for `NSMutableAttributedString`-compatible backing stores.
public final class MutableStringPartialInterface {
	private let content: NSMutableAttributedString
	public var willBeginEditing: (() -> Void)?
	public var didEndEditing: (() -> Void)?
	public var willApplyMutation: ((TextRange, String) -> Void)?

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

extension MutableStringPartialInterface: TextRangeCalculating {
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
	public func applyMutation(_ range: NSRange, string: String, undoManager: UndoManager?) -> MutationOutput<NSRange> {
		let input = string
		let length = input.utf16.count
		let delta = length - range.length

		willApplyMutation?(range, string)

		if let undoManager {
			let existingString = content.attributedSubstring(from: range).string

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
		return applyMutation(mutation.range, string: mutation.string, undoManager: undoManager)
	}
}
