import Foundation

import Rearrange

/// A `TextSystemInterface` that gives an external system a chance to process mutations.
public final class MutationDelegatingTextSystem<Interface: TextSystemInterface> {
	public typealias Position = Interface.Position
	public typealias TextRange = Interface.TextRange
	public typealias Mutator = (_ mutation: TextMutation<TextRange>) throws -> MutationOutput<TextRange>?

	private let wrappedSystem: Interface
	private let mutator: Mutator

	public init(baseInterface: Interface, mutator: @escaping Mutator) {
		self.wrappedSystem = baseInterface
		self.mutator = mutator
	}
}

extension MutationDelegatingTextSystem: TextSystemInterface {
	public func boundingRect(for range: TextRange) -> CGRect? {
		wrappedSystem.boundingRect(for: range)
	}

	public func position(from position: Position, moving direction: TextDirection, by granularity: TextGranularity) -> Position? {
		wrappedSystem.position(from: position, moving: direction, by: granularity)
	}

	public func layoutDirection(at position: Position) -> TextLayoutDirection? {
		wrappedSystem.layoutDirection(at: position)
	}

	public func applyMutation(_ mutation: TextMutation<TextRange>) throws -> MutationOutput<TextRange> {
		if let output = try mutator(mutation) {
			return output
		}

		return try wrappedSystem.applyMutation(mutation)
	}

	public var beginningOfDocument: Position {
		wrappedSystem.beginningOfDocument
	}

	public var endOfDocument: Position {
		wrappedSystem.endOfDocument
	}

	public func textRange(from start: Position, to end: Position) -> TextRange? {
		wrappedSystem.textRange(from: start, to: end)
	}

	public func position(from position: Position, offset: Int) -> Position? {
		wrappedSystem.position(from: position, offset: offset)
	}

	public func offset(from start: Position, to end: Position) -> Int {
		wrappedSystem.offset(from: start, to: end)
	}

	public func compare(_ position: Position, to other: Position) -> ComparisonResult {
		wrappedSystem.compare(position, to: other)
	}

	public func beginEditing() {
		wrappedSystem.beginEditing()
	}

	public func endEditing() {
		wrappedSystem.endEditing()
	}
}

