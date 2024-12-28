public struct CursorSet<TextRange> {
	public let ranges: [TextRange]

	public init(ranges: [TextRange] = []) {
		self.ranges = ranges
	}
}

extension CursorSet: Equatable where TextRange: Equatable {}
extension CursorSet: Hashable where TextRange: Hashable {}
extension CursorSet: Sendable where TextRange: Sendable {}
