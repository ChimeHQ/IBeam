#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

public protocol TextCoordinateProvider {
	associatedtype TextLocation: Comparable

	func closestMatchingVerticalLocation(to location: TextLocation, above: Bool) -> TextLocation?
}
