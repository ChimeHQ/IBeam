#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import Ligature

public struct Cursor<TextLocation: Comparable>: Identifiable {
	public typealias TextRange = Range<TextLocation>

	public let id: UUID
	public var range: TextRange

	public init(range: TextRange) {
		self.range = range
		self.id = UUID()
	}
}

extension Cursor: Comparable {
	public static func < (lhs: Cursor<TextLocation>, rhs: Cursor<TextLocation>) -> Bool {
		lhs.range.lowerBound < rhs.range.lowerBound
	}
}

extension Cursor: Equatable where TextRange: Equatable {}
extension Cursor: Hashable where TextRange: Hashable {}
extension Cursor: Sendable where TextRange: Sendable {}
extension Cursor: Decodable where TextRange: Decodable {}
extension Cursor: Encodable where TextRange: Encodable {}
