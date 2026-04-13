import AppKit

public protocol MultiIndicatorViewDelegate: AnyObject {
	@MainActor
	var numberOfCursors: Int { get }

	@MainActor
	func boundingRectForCursor(at index: Int) -> CGRect?
}

extension UserDefaults {
	func double(for key: String, or value: Double) -> Double {
		guard
			let obj = UserDefaults.standard.value(forKey: key),
			let doubleValue = (obj as? NSNumber)?.doubleValue
		else {
			return value
		}

		return doubleValue
	}
}

public class MultiIndicatorView: NSView {
	enum BlinkState {
		case initial
		case on
		case off

		mutating func toggle() {
			switch self {
			case .initial, .on:
				self = .off
			case .off:
				self = .on
			}
		}
	}

	public typealias BoundingRectProvider = (NSRange) -> CGRect?

	public var color: NSColor? = .black
	public weak var delegate: (any MultiIndicatorViewDelegate)?
	private let blinkPeriodOn: Double
	private let blinkPeriodOff: Double
	private var blinkTimer: Timer? = nil
	private var blinkState = BlinkState.off

	public init() {
		self.blinkPeriodOn = UserDefaults.standard.double(for: "NSTextInsertionPointBlinkPeriodOn", or: 0.56)
		self.blinkPeriodOff = UserDefaults.standard.double(for: "NSTextInsertionPointBlinkPeriodOff", or: 0.56)

		super.init(frame: .zero)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override var isFlipped: Bool {
		true
	}

	public override func draw(_ dirtyRect: NSRect) {
		guard let delegate else { return }

		NSColor.clear.setFill()
		NSBezierPath.fill(dirtyRect)

		if blinkState == .off { return }

		guard let color else { return }

		color.setFill()

		let count = delegate.numberOfCursors

		for index in 0..<count {
			guard let rect = delegate.boundingRectForCursor(at: index) else {
				break
			}
			let indicatorRect = CGRect(
				x: rect.origin.x - 1.0,
				y: rect.origin.y,
				width: 2.0,
				height: rect.size.height
			)

			let path = NSBezierPath(
				roundedRect: indicatorRect,
				xRadius: 1.0,
				yRadius: 1.0
			)

			path.fill()
		}
	}

	public func resetCursorBlinkTimer() {
		self.blinkState = .initial

		scheduleBlinkTimer()
	}

	private func scheduleBlinkTimer() {
		let period: Double = switch blinkState {
		case .initial:
			blinkPeriodOn * 2.0
		case .on:
			blinkPeriodOn
		case .off:
			blinkPeriodOff
		}

		self.blinkTimer?.invalidate()
		self.blinkTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: false) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }

				self.blinkState.toggle()
				self.setNeedsDisplay(self.bounds)

				self.scheduleBlinkTimer()
			}
		}
	}

	override public func viewDidMoveToWindow() {
		resetCursorBlinkTimer()

		super.viewDidMoveToWindow()
	}

	public func install(into view: NSView) {
		self.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(self)

		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: view.topAnchor),
			bottomAnchor.constraint(equalTo: view.bottomAnchor),
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])
	}
}
