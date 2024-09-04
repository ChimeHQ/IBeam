#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import KeyCodes
import Ligature

@MainActor
public struct SelectionProcessor<Tokenizer: TextTokenizer> {
	public typealias Position = Tokenizer.Position
	public typealias TextRange = Tokenizer.TextRange

	public let layoutDirection: UserInterfaceLayoutDirection
	public let tokenizer: Tokenizer
	public let rangeBuilder: Tokenizer.RangeBuilder
	public let positionComparator: Tokenizer.PositionComparator

	public init(
		layoutDirection: UserInterfaceLayoutDirection = .leftToRight,
		tokenizer: Tokenizer,
		rangeBuilder: @escaping Tokenizer.RangeBuilder,
		positionComparator: @escaping Tokenizer.PositionComparator
	) {
		self.layoutDirection = layoutDirection
		self.tokenizer = tokenizer
		self.rangeBuilder = rangeBuilder
		self.positionComparator = positionComparator
	}

	public var isLeftToRight: Bool {
		switch layoutDirection {
		case .leftToRight:
			true
		case .rightToLeft:
			false
		@unknown default:
			true
		}
	}
}

extension SelectionProcessor where Position: Comparable {
	public init(
		layoutDirection: UserInterfaceLayoutDirection = .leftToRight,
		tokenizer: Tokenizer,
		rangeBuilder: @escaping Tokenizer.RangeBuilder,
		positionComparator: @escaping Tokenizer.PositionComparator
	) {
		self.layoutDirection = layoutDirection
		self.tokenizer = tokenizer
		self.rangeBuilder = rangeBuilder
		self.positionComparator = positionComparator
	}
}

extension SelectionProcessor where TextRange == Range<Int> {
	public init(
		layoutDirection: UserInterfaceLayoutDirection = .leftToRight,
		tokenizer: Tokenizer
	) {
		self.init(
			layoutDirection: layoutDirection,
			tokenizer: tokenizer,
			rangeBuilder: { $0..<$1 },
			positionComparator: { $0 < $1 }
		)
	}
}

extension SelectionProcessor {
	public func range(
		from range: TextRange,
		to granularity: TextGranularity,
		in direction: TextDirection
	) -> TextRange? {
		tokenizer.range(from: range, to: granularity, in: direction, rangeBuilder: rangeBuilder)
	}
}

extension SelectionProcessor {
	public func moveLeft(_ input: TextRange) -> TextRange? {
		let start = isLeftToRight ? input.lowerBound : input.upperBound

		guard let newStart = tokenizer.position(from: start, toBoundary: .character, inDirection: .layout(.left)) else {
			return nil
		}

		return rangeBuilder(newStart, newStart)
	}

	public func moveDown(_ input: TextRange) -> TextRange? {
		return tokenizer.range(from: input, to: .character, in: .layout(.down), rangeBuilder: rangeBuilder)
	}
}
