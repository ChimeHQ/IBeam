import Foundation

import Rearrange

public enum TextDirection: Sendable, Hashable {
	case left
	case right
	case up(alignment: CGFloat?)
	case down(alignment: CGFloat?)
	case forward
	case backward
}

public enum TextGranularity: Sendable, Hashable {
	case character
	case word
	case line
}

public enum TextLayoutDirection: Sendable, Hashable {
	case leftToRight
	case rightToLeft
}

public enum SelectionAffinity: Sendable, Hashable {
	case downstream
	case upstream
}

public struct MutationOutput<TextRange> {
	public let selection: TextRange
	public let affinity: SelectionAffinity?
	public let delta: Int

	public init(selection: TextRange, delta: Int, affinity: SelectionAffinity? = nil) {
		self.selection = selection
		self.delta = delta
		self.affinity = affinity
	}
}

extension MutationOutput: Equatable where TextRange: Equatable {}
extension MutationOutput: Hashable where TextRange: Hashable {}
extension MutationOutput: Sendable where TextRange: Sendable {}

public protocol TextSystemInterface : TextRangeCalculating, AnyObject {
	// geometry
	func boundingRect(for range: TextRange) -> CGRect?

	// movement calculation
	func position(from position: Position, moving direction: TextDirection, by granularity: TextGranularity) -> Position?
	func layoutDirection(at position: Position) -> TextLayoutDirection?

	// content mutation
	func beginEditing()
	func endEditing()
	func applyMutation(_ range: TextRange, string: AttributedString) -> MutationOutput<TextRange>?
}

extension TextSystemInterface {
	public var fullDocumentRange: TextRange {
		guard let range = textRange(from: beginningOfDocument, to: endOfDocument) else {
			fatalError("a system must be able to compute fullDocumentRange")
		}

		return range
	}

	public func textRange(from range: TextRange, moving direction: TextDirection, by granularity: TextGranularity) -> TextRange? {
		guard let start = position(from: range.lowerBound, moving: direction, by: granularity) else {
			return nil
		}

		if compare(range.lowerBound, to: range.upperBound) == .orderedSame {
			return textRange(from: start, to: start)
		}

		guard let end = position(from: range.upperBound, moving: direction, by: granularity) else {
			return nil
		}

		return textRange(from: start, to: end)
	}

//	public func intersection(of range: TextRange, with other: TextRange) -> TextRange? {
//		let a = positions(composing: range)
//		let b = positions(composing: other)
//
//		let maxLower = compare(a.0, to: b.0) == .orderedAscending ? b.0 : a.0
//		let minUpper = compare(a.1, to: b.1) == .orderedAscending ? a.1 : b.1
//
//		if compare(maxLower, to: minUpper) == .orderedDescending {
//			return nil
//		}
//
//		return textRange(from: maxLower, to: minUpper)
//	}
}

extension TextSystemInterface {
	/// Creates an initial cursor that represents an empty selection of `beginningOfDocument`.
	public func initialCursor() -> Cursor<TextRange>? {
		guard let range = textRange(from: beginningOfDocument, to: beginningOfDocument) else {
			return nil
		}

		let alignment = boundingRect(for: range)?.origin.x

		return Cursor<TextRange>(range, alignment: alignment, affinity: nil)
	}
}

extension TextSystemInterface where Self: AnyObject, TextRange: Sendable {
	func registerMutationUndo(
		with undoManager: UndoManager?,
		range: TextRange,
		substringProvider: (TextRange) -> (AttributedString, Int)?
	) {
		guard
			let undoManager,
			let (existing, length) = substringProvider(range)
		else {
			return
		}

		let start = range.lowerBound

		guard
			let end = position(from: start, offset: length),
			let inverseRange = textRange(from: start, to: end)
		else {
			return
		}

		undoManager.registerUndo(withTarget: self, handler: { target in
			_ = target.applyMutation(inverseRange, string: existing)
		})
	}
}
