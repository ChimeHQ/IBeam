import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Useful for testing components that rely on the `TextSystem` protocol.
public final class MockTextSystem : TextSystemInterface {
	public typealias TextRange = NSRange
	public typealias TextPosition = Int

	public enum Response: Equatable {
		case position(TextPosition?)
		case boundingRect(CGRect?)
	}

	private var partialSystem: MutableStringPartialInterface
	public var responses: [Response] = []

	public init(_ string: NSAttributedString) {
		self.partialSystem = MutableStringPartialInterface(NSMutableAttributedString(attributedString: string))
	}

	public convenience init(_ string: String) {
		self.init(NSAttributedString(string: string))
	}

	public var attributedString: NSAttributedString {
		partialSystem.attributedString
	}

	public var string: String {
		partialSystem.string
	}

	public func boundingRect(for range: NSRange) -> CGRect? {
		if case let .boundingRect(value) = responses.first {
			responses.removeFirst()

			return value
		}

		return nil
	}

	// movement calculation
	public func position(from position: TextPosition, moving direction: TextDirection, by granularity: TextGranularity) -> TextPosition? {
		switch responses.removeFirst() {
		case let .position(value):
			return value
		default:
			fatalError("wrong return type")
		}
	}

	public func position(from start: TextPosition, offset: Int) -> TextPosition? {
		partialSystem.position(from: start, offset: offset)
	}

	public func layoutDirection(at position: TextPosition) -> TextLayoutDirection? {
		partialSystem.layoutDirection(at: position)
	}

	// range calculation
	public var beginningOfDocument: TextPosition {
		partialSystem.beginningOfDocument
	}

	public var endOfDocument: TextPosition {
		partialSystem.endOfDocument
	}

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
	public func beginEditing() {
		partialSystem.beginEditing()
	}

	public func endEditing() {
		partialSystem.endEditing()
	}

	public func applyMutation(_ range: TextRange, string: AttributedString) -> MutationOutput<TextRange>? {
		partialSystem.applyMutation(range, string: string, undoManager: nil)
	}
}
