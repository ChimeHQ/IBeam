import Testing
import IBeam

class MockCoordinateProvider: TextCoordinateProvider {
	func closestMatchingVerticalLocation(to location: Int, above: Bool) -> Int? {
		let offset = above ? -5 : 5

		return location + offset
	}
}

final class MultiCursorStateTests {
	@Test
	func addCursorBelow() async throws {
		let cursor = Cursor(range: 0..<10)
		let provider = MockCoordinateProvider()
		var state = MultiCursorState(cursors: [cursor], coordinateProvider: provider)

		state.addCursorBelow()

		#expect(state.cursors.map(\.range) == [0..<10, 5..<15])
	}
}
