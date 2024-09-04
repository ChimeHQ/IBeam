import Foundation

public struct Cursor<TextRange>: Identifiable {
	public let id: UUID
	public var textRanges: [TextRange]

	public init(textRanges: [TextRange]) {
		self.textRanges = textRanges
		self.id = UUID()
	}

	public init(textRange: TextRange) {
		self.init(textRanges: [textRange])
	}
}

extension Cursor: Equatable where TextRange: Equatable {}
extension Cursor: Hashable where TextRange: Hashable {}
extension Cursor: Sendable where TextRange: Sendable {}
extension Cursor: Decodable where TextRange: Decodable {}
extension Cursor: Encodable where TextRange: Encodable {}
