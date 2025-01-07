import AppKit

import IBeam
import Glyph
import Ligature

extension IBeam.TextGranularity {
	var ligatureGranulaity: Ligature.TextGranularity {
		switch self {
		case .character: .character
		case .word: .word
		case .line: .line
		}
	}
}

@MainActor
public struct IBeamTextViewSystem {
	let textView: NSTextView
	let tokenizer: UTF16CodePointTextViewTextTokenizer

	public init(textView: NSTextView) {
		self.textView = textView
		self.tokenizer = UTF16CodePointTextViewTextTokenizer(textView: textView)
	}

	private var partialSystem: MutableStringPartialSystem {
		MutableStringPartialSystem(textView.textStorage ?? NSTextStorage())
	}
}

extension IBeamTextViewSystem : @preconcurrency IBeam.TextSystemInterface {
	public typealias TextRange = NSRange
	public typealias TextPosition = Int

	public func location(for position: TextPosition) -> CGFloat? {
		tokenizer.location(for: position)
	}

	// movement calculation
	public func position(from position: TextPosition, moving direction: IBeam.TextDirection, by granularity: IBeam.TextGranularity) -> TextPosition? {
		let ligGranularity =  granularity.ligatureGranulaity

		switch direction {
		case .forward:
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .storage(.forward))
		case .backward:
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .storage(.backward))
		case .left:
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .layout(.left))
		case .right:
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .layout(.right))
		case let .down(alignment):
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .layout(.down), alignment: alignment)
		case let .up(alignment):
			return tokenizer.position(from: position, toBoundary: ligGranularity, inDirection: .layout(.up), alignment: alignment)
		}
	}

	public func position(from start: TextPosition, offset: Int) -> TextPosition? {
		partialSystem.position(from: start, offset: offset)
	}

	public func layoutDirection(at position: TextPosition) -> IBeam.TextLayoutDirection? {
		partialSystem.layoutDirection(at: position)
	}

	// range calculation
	public var beginningOfDocument: TextPosition { partialSystem.beginningOfDocument }
	public var endOfDocument: TextPosition { partialSystem.endOfDocument }

	public func compare(_ position: TextPosition, to other: TextPosition) -> ComparisonResult {
		partialSystem.compare(position, to: other)
	}

	public func positions(composing range: TextRange) -> (TextPosition, TextPosition) {
		partialSystem.positions(composing: range)
	}

	public func textRange(from start: TextPosition, to end: TextPosition) -> TextRange? {
		partialSystem.textRange(from: start, to: end)
	}

	// content mutation
	public func beginEditing() { partialSystem.beginEditing() }
	public func endEditing() { partialSystem.endEditing() }

	public func applyMutation(_ range: TextRange, string: AttributedString) -> MutationOutput<TextRange>? {
		partialSystem.applyMutation(range, string: string, undoManager: nil)
	}
}
