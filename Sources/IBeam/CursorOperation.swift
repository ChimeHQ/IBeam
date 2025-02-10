enum CursorOperationError: Error {
	case insertArrayCountMismatch
}

public enum CursorOperation<TextRange> {
	case resetToSingle(Cursor<TextRange>)
	case add(TextRange)
	case addAbove
	case addBelow

	// this is nearly a map
	public func translate<OtherRange>(with translator: (TextRange) -> OtherRange?) -> CursorOperation<OtherRange>? {
		switch self {
		case .addAbove:
			return .addAbove
		case .addBelow:
			return .addBelow
		case let .add(textRange):
			guard let otherRange = translator(textRange) else {
				return nil
			}
			
			return .add(otherRange)
		case let .resetToSingle(cursor):
			guard let otherRange = translator(cursor.textRange) else {
				return nil
			}
			
			let newCursor = Cursor<OtherRange>(
				id: cursor.id,
				textRange: otherRange,
				alignment: cursor.alignment,
				affinity: cursor.affinity
			)
			
			return .resetToSingle(newCursor)
		}
	}
}
