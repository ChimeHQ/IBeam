#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

import Ligature

#if os(macOS) || os(iOS) || os(visionOS)
public struct Cursor {
	public let ranges: [NSTextRange]
	public let affinity: NSTextSelection.Affinity
	public let granularity: TextGranularity

	public init(ranges: [NSTextRange], affinity: NSTextSelection.Affinity, granularity: TextGranularity = .character) {
		self.ranges = ranges
		self.affinity = affinity
		self.granularity = granularity
	}

#if os(macOS)
	public init(ranges: [NSTextRange], affinity: NSSelectionAffinity, granularity: TextGranularity = .character) {
		self.ranges = ranges
		self.affinity = NSTextSelection.Affinity(affinity)
		self.granularity = granularity
	}
#endif
}
#endif
