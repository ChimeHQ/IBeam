import Testing
import IBeam

import Ligature

import Foundation

final class SelectionProcessorTests {
	@Test
	@MainActor
	func moveLeft() throws {
		let tokenizer = MockTextTokenizer<Range<Int>>()
		let processor = SelectionProcessor(tokenizer: tokenizer)

		tokenizer.responses = [.position(0)]
		let range = processor.moveLeft(1..<1)

		#expect(tokenizer.requests == [.position(1, .character, .layout(.left))])
		#expect(range == 0..<0)
	}

	@Test
	@MainActor
	func moveDown() throws {
		let tokenizer = MockTextTokenizer<Range<Int>>()
		let processor = SelectionProcessor(tokenizer: tokenizer)

		tokenizer.responses = [.position(10), .position(10)]
		let range = processor.moveDown(1..<1)

		#expect(tokenizer.requests == [.position(1, .character, .layout(.down)), .position(1, .character, .layout(.down))])
		#expect(range == 10..<10)
	}
}
