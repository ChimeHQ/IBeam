import Foundation
import Testing

import IBeam

#if os(macOS)
import AppKit

@MainActor
struct PasteboardTests {
	@Test
	func readSingleString() throws {
		let pasteboard = NSPasteboard.withUniqueName()

		pasteboard.clearContents()
		pasteboard.setPropertyList([1], forType: .multipleTextSelection)
		pasteboard.setString("hello", forType: .string)

		let output = pasteboard.multipleTextSelectionStrings()

		#expect(output == ["hello"])
	}

	@Test
	func readMultipleStrings() throws {
		let pasteboard = NSPasteboard.withUniqueName()

		pasteboard.clearContents()
		pasteboard.setPropertyList([1,1,1], forType: .multipleTextSelection)
		pasteboard.setString("a\nb\nc", forType: .string)

		let output = pasteboard.multipleTextSelectionStrings()

		#expect(output == ["a", "b", "c"])
	}

	@Test
	func writeSingleString() throws {
		let pasteboard = NSPasteboard.withUniqueName()

		pasteboard.clearContents()
		pasteboard.setMultipleTextSelectionStrings(["hello"])

		#expect(pasteboard.string(forType: .string) == "hello")
		#expect(pasteboard.propertyList(forType: .multipleTextSelection) as? [Int] == [1])
	}

	@Test
	func writeMultipleStrings() throws {
		let pasteboard = NSPasteboard.withUniqueName()

		pasteboard.clearContents()
		pasteboard.setMultipleTextSelectionStrings(["a", "b", "c"])

		#expect(pasteboard.string(forType: .string) == "a\nb\nc")
		#expect(pasteboard.propertyList(forType: .multipleTextSelection) as? [Int] == [1, 1, 1])
	}
}

#endif
