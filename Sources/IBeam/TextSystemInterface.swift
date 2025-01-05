import Foundation

public enum TextDirection {
	case left
	case right
	case up(alignment: CGFloat?)
	case down(alignment: CGFloat?)
	case forward
	case backward
}

public enum TextGranularity {
	case character
	case word
	case line
}

public enum TextLayoutDirection {
	case leftToRight
	case rightToLeft
}

public struct MutationOutput<TextRange> {
	public let selection: TextRange
	public let delta: Int

	public init(selection: TextRange, delta: Int) {
		self.selection = selection
		self.delta = delta
	}
}

public protocol TextSystemInterface<TextRange, TextPosition> {
	associatedtype TextRange
	associatedtype TextPosition

	// geometry
	func boundingRect(for range: TextRange) -> CGRect?

	// movement calculation
	func position(from position: TextPosition, moving direction: TextDirection, by granularity: TextGranularity) -> TextPosition?
	func position(from start: TextPosition, offset: Int) -> TextPosition?
	func layoutDirection(at position: TextPosition) -> TextLayoutDirection?

	// range calculation
	var beginningOfDocument: TextPosition { get }
	var endOfDocument: TextPosition { get }
	func compare(_ position: TextPosition, to other: TextPosition) -> ComparisonResult
	func positions(composing range: TextRange) -> (TextPosition, TextPosition)
	func textRange(from start: TextPosition, to end: TextPosition) -> TextRange?

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

	public func textRange(offseting range: TextRange, by offset: Int) -> TextRange? {
		if offset == 0 {
			return range
		}
		
		let positions = positions(composing: range)

		guard
			let start = position(from: positions.0, offset: offset),
			let end = position(from: positions.1, offset: offset)
		else {
			return nil
		}

		return textRange(from: start, to: end)
	}

	public func textRange(from range: TextRange, moving direction: TextDirection, by granularity: TextGranularity) -> TextRange? {
		let positions = positions(composing: range)

		guard let start = position(from: positions.0, moving: direction, by: granularity) else {
			return nil
		}

		if compare(positions.0, to: positions.1) == .orderedSame {
			return textRange(from: start, to: start)
		}

		guard let end = position(from: positions.1, moving: direction, by: granularity) else {
			return nil
		}

		return textRange(from: start, to: end)
	}

	public func intersection(of range: TextRange, with other: TextRange) -> TextRange? {
		let a = positions(composing: range)
		let b = positions(composing: other)

		let maxLower = compare(a.0, to: b.0) == .orderedAscending ? b.0 : a.0
		let minUpper = compare(a.1, to: b.1) == .orderedAscending ? a.1 : b.1

		if compare(maxLower, to: minUpper) == .orderedDescending {
			return nil
		}

		return textRange(from: maxLower, to: minUpper)
	}
}

extension TextSystemInterface {
	/// Creates an initial cursor that represents an empty selection of `beginningOfDocument`.
	public func initialCursor() -> Cursor<TextRange>? {
		guard let range = textRange(from: beginningOfDocument, to: beginningOfDocument) else {
			return nil
		}

		let alignment = boundingRect(for: range)?.origin.x

		return Cursor<TextRange>(range, alignment: alignment)
	}
}
