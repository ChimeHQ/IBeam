import Foundation

//public struct TextStorage<TextRange> {
//	public struct MutationOutput {
//		public let selection: TextRange
//		public let delta: Int
//
//		public init(selection: TextRange, delta: Int) {
//			self.selection = selection
//			self.delta = delta
//		}
//	}
//
//	public let beginEditing: () -> Void
//	public let endEditing: () -> Void
//	public let applyMutation: (TextRange, AttributedString) -> MutationOutput?
//
//	public init(
//		beginEditing: @escaping () -> Void = {},
//		endEditing: @escaping () -> Void = {},
//		applyMutation: @escaping (TextRange, AttributedString) -> MutationOutput?
//	) {
//		self.beginEditing = beginEditing
//		self.endEditing = endEditing
//		self.applyMutation = applyMutation
//	}
//}
//
//extension TextStorage {
//	public func rangeTranslated<NewRange>(with translator: RangeTranslator<TextRange, NewRange>) -> TextStorage<NewRange> {
//		TextStorage<NewRange>.init(
//			beginEditing: {
//				self.beginEditing()
//			},
//			endEditing: {
//				self.endEditing()
//			},
//			applyMutation: { range, attrString in
//				guard
//					let newRange = translator.from(range),
//					let output = self.applyMutation(newRange, attrString),
//					let outRange = translator.to(output.selection)
//				else {
//					return nil
//				}
//
//				return TextStorage<NewRange>.MutationOutput(selection: outRange, delta: output.delta)
//			}
//		)
//	}
//}
//
//#if os(macOS)
//import AppKit
//
//extension TextStorage where TextRange == NSRange {
//	@MainActor
//	public init(_ storage: NSTextStorage, undoManager: UndoManager? = nil) {
//		self.init(
//			beginEditing: {
//				storage.beginEditing()
//			},
//			endEditing: {
//				storage.endEditing()
//			},
//			applyMutation: { range, attrString in
//				let nsAttrString = NSAttributedString(attrString)
//				let length = nsAttrString.length
//
//				let existingString = storage.attributedSubstring(from: range)
//
//				undoManager?.registerMainActorUndo(withTarget: storage, handler: { target in
//					target.replaceCharacters(in: range, with: existingString)
//				})
//
//				storage.replaceCharacters(in: range, with: nsAttrString)
//
//				let delta = length - range.length
//				let position = min(range.lowerBound + length, storage.length)
//
//				let newSelection = NSRange(position..<position)
//
//				return MutationOutput(selection: newSelection, delta: delta)
//			}
//		)
//	}
//
//	@MainActor
//	public init(_ textView: NSTextView) {
//		self.init(
//			beginEditing: {
//				textView.textStorage?.beginEditing()
//			},
//			endEditing: {
//				textView.textStorage?.endEditing()
//			},
//			applyMutation: { range, attrString in
//				guard let textStorage = textView.textStorage else {
//					return TextStorage.MutationOutput(selection: range, delta: 0)
//				}
//
//				let storage = TextStorage(textStorage, undoManager: textView.undoManager)
//
//				return storage.applyMutation(range, attrString)
//			}
//		)
//	}
//}

#if os(macOS)
import AppKit

extension NSTextStorage {
	@MainActor
	public func applyMutation(in range: NSRange, string: AttributedString, undoManager: UndoManager?) -> MutationOutput<NSRange> {
		let nsAttrString = NSAttributedString(string)
		let length = nsAttrString.length

		let existingString = attributedSubstring(from: range)

		undoManager?.registerMainActorUndo(withTarget: self, handler: { target in
			target.replaceCharacters(in: range, with: existingString)
		})

		replaceCharacters(in: range, with: nsAttrString)

		let delta = length - range.length
		let position = min(range.lowerBound + length, self.length)

		let newSelection = NSRange(position..<position)

		return MutationOutput<NSRange>(selection: newSelection, delta: delta)
	}
}

#endif
