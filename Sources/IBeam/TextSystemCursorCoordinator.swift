#if os(macOS)
import AppKit

@available(macOS 14.0, *)
@MainActor
public final class TextSystemCursorCoordinator<System: TextSystem> where System.TextRange == NSRange {
	typealias CursorState = MultiCursorState<System>

	private let textView: NSTextView
	private let indicatorState: TextViewIndicatorState
	private let cursorState: CursorState
	private var selectionNotification: NSObjectProtocol?
	private var viewCursor: Cursor<CursorState.TextRange>
	private var mutatingSelection = false

	public init(textView: NSTextView, system: System) {
		self.textView = textView

		self.viewCursor = system.initialCursor()!
		self.indicatorState = TextViewIndicatorState(textView: textView, viewCursorId: viewCursor.id)
		indicatorState.boundingRectProvider = { system.boundingRect(for: $0)?.integral }

		self.cursorState = CursorState(
			cursors: [viewCursor],
			system: system
		)

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
	}

	private func selectionChanged() {
		if mutatingSelection {
			return
		}

		viewCursor.textRange = textView.selectedRange()

		cursorState.mutateCursors(with: .resetToSingle(viewCursor))
	}

	private func cursorsUpdated(added: Set<UUID>, deleted: Set<UUID>, changed: Set<UUID>) {
		for id in deleted {
			indicatorState.removeIndicator(with: id)
		}

		let existing = added.union(changed)

		// this is inefficient
		let existingCursors = cursorState.cursors.filter({ existing.contains($0.id) })

		mutatingSelection = true

		for cursor in existingCursors {
			indicatorState.updateIndictor(with: cursor.textRange, for: cursor.id)
		}

		mutatingSelection = false
	}

	public func processOperation(_ operation: InputOperation) {
		mutatingSelection = true
		cursorState.apply(operation)
		mutatingSelection = false

		// if we have removed all cursors, process a selection change to
		// restore our state
		if cursorState.cursors.isEmpty {
			selectionChanged()
		}
	}

	public func mutateCursors(with operation: CursorOperation<NSRange>) {
		cursorState.mutateCursors(with: operation)
	}
}
#endif
