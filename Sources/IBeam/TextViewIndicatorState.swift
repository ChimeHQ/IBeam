#if os(macOS)
import AppKit

/// Manages cursor view isntances within an NSTextView.
///
/// This type maintains a weak reference to the underlying text view.
@available(macOS 14.0, *)
@MainActor
public final class TextViewIndicatorState {
	public typealias BoundingRectProvider = (NSRange) -> CGRect?

	private weak var textView: NSTextView?
	public let viewCursorId: UUID

	private var indicators: [UUID: NSTextInsertionIndicator] = [:]
	public var boundingRectProvider: BoundingRectProvider = { _ in nil }

	public init(textView: NSTextView, viewCursorId: UUID) {
		self.textView = textView
		self.viewCursorId = viewCursorId
	}

	private var indicatorViews: [NSTextInsertionIndicator] {
		guard let textView else { return [] }

		return textView.subviews
			.compactMap { $0 as? NSTextInsertionIndicator }
			.sorted { a, b in
				a.frame.minY < b.frame.minY
			}
	}

	private func synchronizeCusorBlinking() {
		for view in indicatorViews {
			view.displayMode = .hidden
			view.displayMode = .automatic
		}

		textView?.updateInsertionPointStateAndRestartTimer(true)
	}

	public func removeIndicator(with id: UUID) {
		if id == viewCursorId {
			return
		}

		indicators[id]!.removeFromSuperview()
		indicators[id] = nil
	}

	public func updateIndictor(with range: NSRange, affinity: NSSelectionAffinity, for id: UUID) {
		guard let textView else { return }
		
		if id == viewCursorId {
			textView.setSelectedRange(range, affinity: affinity, stillSelecting: false)
			return
		}

		// only insertion points are visible
		guard range.length == 0 else {
			if indicators[id] != nil {
				removeIndicator(with: id)
			}

			return
		}

		guard let rect = boundingRectProvider(range) else {
			return
		}

		defer { synchronizeCusorBlinking() }

		if let indicator = indicators[id] {
			indicator.frame = rect
			return
		}

		let indicator = NSTextInsertionIndicator(frame: rect)

		indicator.color = textView.insertionPointColor

		indicators[id] = indicator

		textView.addSubview(indicator)
	}
}
#endif
