import Foundation

public struct Cursor<TextRange> {
	public let id: UUID
	public var textRange: TextRange
	public var alignment: CGFloat?
	public var affinity: SelectionAffinity?

	public init(_ textRange: TextRange, alignment: CGFloat?, affinity: SelectionAffinity?) {
		self.textRange = textRange
		self.alignment = alignment
		self.id = UUID()
		self.affinity = affinity
	}

	init(id: UUID, textRange: TextRange, alignment: CGFloat?, affinity: SelectionAffinity?) {
		self.id = id
		self.textRange = textRange
		self.alignment = alignment
		self.affinity = affinity
	}
}

extension Cursor: Equatable where TextRange: Equatable {}
extension Cursor: Hashable where TextRange: Hashable {}
extension Cursor: Sendable where TextRange: Sendable {}

extension Cursor: Identifiable {}

extension Cursor: CustomStringConvertible {
	public var description: String {
		let alignmentStr = alignment.map { $0.description } ?? "-"
		let affinityStr = affinity.map { String(describing: $0) } ?? "-"

		return "<Cursor \(id) \(textRange) \(alignmentStr) \(affinityStr)>"
	}
}
