import Foundation

public struct Cursor<TextRange> {
	public let id: UUID
	public var textRange: TextRange
	public var alignment: CGFloat?

	public init(_ textRange: TextRange, alignment: CGFloat?) {
		self.textRange = textRange
		self.alignment = alignment
		self.id = UUID()
	}

	init(id: UUID, textRange: TextRange, alignment: CGFloat?) {
		self.id = id
		self.textRange = textRange
		self.alignment = alignment
	}
}

extension Cursor: Equatable where TextRange: Equatable {}
extension Cursor: Hashable where TextRange: Hashable {}
extension Cursor: Sendable where TextRange: Sendable {}
extension Cursor: Decodable where TextRange: Decodable {}
extension Cursor: Encodable where TextRange: Encodable {}

extension Cursor: Identifiable {}

extension Cursor: CustomStringConvertible {
	public var description: String {
		let str = alignment.map { $0.description } ?? "-"

		return "<Cursor \(id) \(textRange) \(str)>"
	}
}
