enum CursorOperationError: Error {
	case insertArrayCountMismatch
}

public enum CursorOperation<TextRange> {
	case reset([TextRange])
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
		case .reset(let ranges):
			let transformed = ranges.compactMap { translator($0) }

			return .reset(transformed)
		}
	}
}
