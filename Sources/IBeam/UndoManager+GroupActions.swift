import Foundation

extension UndoManager {
	var isActive: Bool {
		isUndoing || isRedoing
	}
}

extension UndoManager {
	/// A pair of actions to invoke when an undo group is entered/exited as part of an undo or redo.
	@preconcurrency @MainActor
	public struct GroupActions<T: AnyObject> {
		public typealias Action = (_ target: T) -> Void

		public var enter: Action
		public var leave: Action

		public init(
			enter: @escaping Action,
			leave: @escaping Action = { _ in }
		) {
			self.enter = enter
			self.leave = leave
		}

		/// Apply the actions to a group.
		///
		/// The actions will run even if the UndoManager argument is nil. If you don't want this behavior, check out the `UndoManager.withUndoGrouping` variant.
		public func withUndoGrouping(for undoManager: UndoManager?, target: T, _ block: () -> Void) {
			guard let undoManager else {
				enter(target)
				block()
				leave(target)
				return
			}

			undoManager.withUndoGrouping(target: target, actions: self, block)
		}
	}

	private func invokeAction<T: AnyObject>(for target: T, _ action: @escaping (_ undoing: Bool, _ target: T) -> Void) {
		action(isUndoing, target)

		registerUndo(withTarget: target) { [weak self] target in
			self?.invokeAction(for: target, action)
		}
	}

	public func withUndoGrouping<T: AnyObject>(target: T, actions: GroupActions<T>, _ block: () -> Void) {
		beginUndoGrouping()

		invokeAction(for: target) { undoing, innerTarget in
			if undoing {
				actions.leave(innerTarget)
			} else {
				actions.enter(innerTarget)
			}
		}

		block()

		invokeAction(for: target) { undoing, innerTarget in
			if undoing {
				actions.enter(innerTarget)
			} else {
				actions.leave(innerTarget)
			}
		}

		endUndoGrouping()
	}
}
