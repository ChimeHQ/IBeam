//public struct RangeTranslator<RangeA, RangeB> {
//	public let to: (RangeA) -> RangeB?
//	public let from: (RangeB) -> RangeA?
//
//	public init(
//		to: @escaping (RangeA) -> RangeB?,
//		from: @escaping (RangeB) -> RangeA?
//	) {
//		self.to = to
//		self.from = from
//	}
//}

//#if os(macOS)
//import AppKit
//
//extension NSTextView {
//	public var rangeTranslator: RangeTranslator<NSRange, Ligature.TextRange> {
//		.init(
//			to: { [weak self] in
//				self?.textRange(from: $0)
//			},
//			from: { [weak self] textRange in
//				guard let self else { return nil }
//
//				return  NSRange(textRange, textView: self)
//			}
//		)
//	}
//}
//#endif
