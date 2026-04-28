#if os(macOS)
import AppKit

import Rearrange

@MainActor
public final class TextSystemCursorCoordinator<System: TextSystemInterface> {
	public typealias CursorState = MultiCursorState<System>

	private weak var textView: NSTextView?
	private let indicatorView: MultiIndicatorView
	public let cursorState: CursorState
	private var selectionNotification: NSObjectProtocol?
	private var viewCursor: Cursor<CursorState.TextRange>
	private var mutatingSelection = false

	public init(textView: NSTextView, system: System) {
		self.textView = textView

		self.viewCursor = system.initialCursor()!
		self.indicatorView = MultiIndicatorView()

		self.cursorState = CursorState(
			cursors: [viewCursor],
			system: system
		)

		// install cursor view
		indicatorView.install(into: textView)

		self.selectionNotification = NotificationCenter.default.addObserver(
			forName: NSTextView.didChangeSelectionNotification,
			object: textView,
			queue: .main,
			using: { [weak self] _ in
				MainActor.assumeIsolated {
					self?.selectionChanged()
				}
			}
		)

		cursorState.cursorsChanged = { [weak self] in self?.cursorsUpdated(added: $0, deleted: $1, changed: $2) }
		cursorState.undoManagerProvider = { [textView] in textView.undoManager }

		indicatorView.delegate = cursorState
	}

	private var textSystem: System {
		cursorState.textSystem
	}

	private func selectionChanged() {
		let undoManager = textView?.undoManager

		let undoActive = undoManager?.isActive ?? false

		indicatorView.resetCursorBlinkTimer()

		guard let textView, mutatingSelection == false, undoActive == false else {
			return
		}

		let ranges = textView.selectedRanges
			.compactMap {
				let range = $0.rangeValue

				return textSystem.textRange(from: range)
			}

		cursorState.mutateCursors(with: .reset(ranges))
	}

	private func withSelectionMutation(_ block: () throws -> Void) rethrows {
		mutatingSelection = true
		defer { mutatingSelection = false }

		try block()
	}

	private func cursorsUpdated(added: Set<UUID>, deleted: Set<UUID>, changed: Set<UUID>) {
		guard let textView else { return }

		indicatorView.needsDisplay = true

		withSelectionMutation {
			textView.selectedRanges = cursorState.cursorSet.ranges.map {
				let range = NSRange($0, with: cursorState.textSystem)

				return NSValue(range: range)
			}
		}
	}

	public var insertionPointColor: NSColor? {
		get { indicatorView.color }
		set { indicatorView.color = newValue }
	}

	public func processOperation(_ operation: InputOperation) {
		defer {
			// if we have removed all cursors, process a selection change to
			// restore our state
			if cursorState.cursors.isEmpty {
				selectionChanged()
			}
		}

		withSelectionMutation {
			cursorState.apply(operation)
		}
	}

	public func mutateCursors(with operation: CursorOperation<System.TextRange>) {
		cursorState.mutateCursors(with: operation)
	}

	public func didChangeText(in range: NSRange, delta: Int) {
		let textRange = textSystem.textRange(from: range)!

		// if this results in changes to the cursor locations, we'll get our callback
		cursorState.didChangeText(in: textRange, delta: delta)
	}
}

#endif
