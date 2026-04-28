#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension NSAttributedString {
	public func layoutDirection(at position: Int) -> TextLayoutDirection? {
		if position >= length {
			return nil
		}

		let attrs = attributes(at: position, effectiveRange: nil)
		guard let direction = attrs[.writingDirection] as? NSNumber else {
			return nil
		}

		return switch direction.intValue {
		case NSWritingDirection.leftToRight.rawValue:
			.leftToRight
		case NSWritingDirection.rightToLeft.rawValue:
			.rightToLeft
		default:
			nil
		}
	}
}
