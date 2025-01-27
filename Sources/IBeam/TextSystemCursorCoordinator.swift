#if os(macOS)
import AppKit

import Rearrange

@available(macOS 14.0, *)
@MainActor
public final class TextSystemCursorCoordinator<System: TextSystemInterface> where System.TextRange == NSRange {
	public typealias CursorState = MultiCursorState<System>

	private weak var textView: NSTextView?
	private let indicatorState: TextViewIndicatorState
	public let cursorState: CursorState
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
		cursorState.undoManagerProvider = { [textView] in textView.undoManager }
	}

	private func selectionChanged() {
		let undoManager = textView?.undoManager

		let undoActive = undoManager?.isRedoing ?? false || undoManager?.isUndoing ?? false

		guard let textView, mutatingSelection == false, undoActive == false else {
			return
		}

		viewCursor.textRange = textView.selectedRange()

		cursorState.mutateCursors(with: .resetToSingle(viewCursor))
	}

	private func withSelectionMutation(_ block: () throws -> Void) rethrows {
		mutatingSelection = true
		defer { mutatingSelection = false }

		try block()
	}

	private func cursorsUpdated(added: Set<UUID>, deleted: Set<UUID>, changed: Set<UUID>) {
		for id in deleted {
			indicatorState.removeIndicator(with: id)
		}

		let existing = added.union(changed)

		// this is inefficient
		let existingCursors = cursorState.cursors.filter({ existing.contains($0.id) })

		withSelectionMutation {
			// I'm not 100% sure, yet, if/how to choose this correctly in all cases.
			let affinity = NSSelectionAffinity.downstream

			for cursor in existingCursors {
				indicatorState.updateIndictor(with: cursor.textRange, affinity: affinity, for: cursor.id)
			}

			textView?.selectedRanges = cursorState.cursorSet.ranges.map { NSValue(range: $0) }
		}
	}

	public func processOperation(_ operation: InputOperation) throws {
		defer {
			// if we have removed all cursors, process a selection change to
			// restore our state
			if cursorState.cursors.isEmpty {
				selectionChanged()
			}
		}

		try withSelectionMutation {
			try cursorState.apply(operation)
		}
	}

	public func mutateCursors(with operation: CursorOperation<NSRange>) {
		cursorState.mutateCursors(with: operation)
	}

	public func didChangeText(in range: NSRange, delta: Int) {
		// if this results in changes to the cursor locations, we'll get our callback
		cursorState.didChangeText(in: range, delta: delta)
	}
}
#endif
