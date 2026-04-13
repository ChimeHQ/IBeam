import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Rearrange

/// Useful for testing components that rely on the `TextSystem` protocol.
@preconcurrency @MainActor
public final class MockTextSystem: @MainActor TextSystemInterface {
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

	public var willApplyMutation: ((TextRange, String) -> Void)? {
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

	public func layoutDirection(at position: TextPosition) -> TextLayoutDirection? {
		partialSystem.layoutDirection(at: position)
	}

	// range calculation
	public var endOfDocument: TextPosition {
		partialSystem.endOfDocument
	}

	// content mutation
	public func beginEditing() {
		partialSystem.beginEditing()
	}

	public func endEditing() {
		partialSystem.endEditing()
	}

	public func applyMutation(_ mutation: TextMutation<TextRange>) -> MutationOutput<TextRange> {
		let undoManager = undoManagerProvider?()

		return partialSystem.applyMutation(mutation, undoManager: undoManager)
	}
}

extension MockTextSystem: @MainActor Equatable {
	public static func == (lhs: MockTextSystem, rhs: MockTextSystem) -> Bool {
		lhs === rhs
	}
}
