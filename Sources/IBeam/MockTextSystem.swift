import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Rearrange

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
	public var undoManagerProvider: (() -> UndoManager?)?

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

	public var willApplyMutation: ((TextRange, NSAttributedString) -> Void)? {
		get { partialSystem.willApplyMutation }
		set { partialSystem.willApplyMutation = newValue }
	}

	public var willBeginEditing: (() -> Void)? {
		get { partialSystem.willBeginEditing }
		set { partialSystem.willBeginEditing = newValue }
	}

	public var didEndEditing: (() -> Void)? {
		get { partialSystem.didEndEditing }
		set { partialSystem.didEndEditing = newValue }
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
			print("wrong return type")
			return nil
		}
	}

	public func offset(from: Position, to toPosition: Position) -> Int {
		partialSystem.offset(from: from, to: toPosition)
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
		let undoManager = undoManagerProvider?()

		return partialSystem.applyMutation(range, string: string, undoManager: undoManager)
	}
}

extension MockTextSystem : Equatable {
	public static func == (lhs: MockTextSystem, rhs: MockTextSystem) -> Bool {
		lhs === rhs
	}
}
