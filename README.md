<div align="center">

[![Build Status][build status badge]][build status]
[![Platforms][platforms badge]][platforms]
[![Documentation][documentation badge]][documentation]
[![Matrix][matrix badge]][matrix]

</div>

# IBeam
A Swift library for multi-cursor support

Features:

- Text system-agnostic
- Includes support for `NSTextView` and `UITextView`
- Lazy/deferred cursor operation evaluation

> [!WARNING]
> Still early days. Lazy evaluation in particular is a work in progress.

## Integration

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/IBeam", branch: "main")
]
```

Supported Traits:

- `ViewSupport`: Enabled the `IBeamTextViewSystem` type, used for direct `NS/UITextView` integration.

## Concepts

The `MultiCursorState` type accepts two kinds of events to manage cursor states: `InputOperation` and `CursorOperation`.

The `InputOperation` type models the use actions that affect selection and text state. This closely mirrors selectors within `NSResponder`. The `CursorOperation` type models actions that affect the number active cursors. The client of a `MultiCursorState` instance feeds in these two types of operations, and the state manages querying and relaying mutations to its `TextSystemInterface` instance to execute those operations.

To support large numbers of cursors, `MultiCursorState` plays tricks. In particular, it may delay, combine, or otherwise reorder operations if can do so in a way that does not impact visible user state. These can be essential for performance, but you can always force a fully up-to-date system with the `ensureOperationsProcessed` methods.

## Implementing a Text System

IBeam needs to be provided with an interface to the underlying text system. The functionality required to do this is non-trivial, especially when the concepts of "range" and "text location" are fully generic.

The `IBeamTextViewSystem` type is available for direct integration with `NS/UITextView`, compatible with both TextKit 1 and 2. It is gated behind the `ViewSupport` package trait. However, this is unlikely to meet the needs of sophisticated users. If you need or want to implement a custom system, take a look at the `TextSystemInterface` protocol. It offers a lot of flexibility, particularly around how your system applies text mutations.

If you need or want to implement a custom system, take a look at the `TextSystemInterface` protocol. It offers a lot of flexibility, particularly around how your system applies text mutations.

If you are on macOS 14.0 or greater, you can use the `TextViewIndicatorState` type to manage cursor views.

## Pasteboard Support

[NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard/pasteboardtype/multipletextselection) supports mutiple text selection. However, as far as I can tell the actual format used is undocumented. There are two extension methods you can use to encoded and decode data this way within your view system. These include the ability to control line endings.

```swift
extension NSPasteboard {
    func multipleTextSelectionStrings(with seperator: String = "\n") -> [String]?
    func setMultipleTextSelectionStrings(_ strings: [String], with seperator: String = "\n")
}
```

## Usage

Here's an example of using a `TextSystemCursorCoordinator` and `IBeamTextViewSystem` that ties everything together for an `NSTextView`. Unfortunately, a subclass is required, but it's fairly minimal.

This also makes use of the [KeyCodes][] library to make modifier key checks easier.

[KeyCodes]: https://github.com/chimeHQ/KeyCodes

```swift
import AppKit

import KeyCodes
import IBeam

extension KeyModifierFlags {
    var addingCursor: Bool {
        subtracting(.numericPad) == [.control, .shift]
    }
}

open class MultiCursorTextView: NSTextView {
    private lazy var coordinator = TextSystemCursorCoordinator(
        textView: self,
        system: IBeamTextViewSystem(textView: self)
    )

    public var operationProcessor: (InputOperation) -> Void = { _ in }
    public var cursorOperationHandler: (CursorOperation<NSRange>) -> Void = { _ in }

    override public init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)

        self.operationProcessor = coordinator.processOperation
        self.cursorOperationHandler = coordinator.mutateCursors
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MultiCursorTextView {
    open override func insertText(_ input: Any, replacementRange: NSRange) {
        // also should handle replacementRange values

        let attrString: AttributedString

        switch input {
        case let string as String:
            let container = AttributeContainer(typingAttributes)

            attrString = AttributedString(string, attributes: container)
        case let string as NSAttributedString:
            attrString = AttributedString(string)
        default:
            fatalError("This API should be called with NSString or NSAttributedString only")
        }

        operationProcessor(.insertText(attrString))
    }

    open override func doCommand(by selector: Selector) {
        if let op = InputOperation(selector: selector) {
            operationProcessor(op)
            return
        }

        super.doCommand(by: selector)
    }

    // this enable correct routing for the mouse down
    open override func menu(for event: NSEvent) -> NSMenu? {
        if event.keyModifierFlags?.addingCursor == true {
            return nil
        }

        return super.menu(for: event)
    }

    open override func mouseDown(with event: NSEvent) {
        guard event.keyModifierFlags?.addingCursor == true else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let range = NSRange(index..<index)

        cursorOperationHandler(.add(range))
    }

    open override func keyDown(with event: NSEvent) {
        let flags = event.keyModifierFlags?.subtracting(.numericPad) ?? []
        let key = event.keyboardHIDUsage

        switch (flags, key) {
        case ([.control, .shift], .keyboardUpArrow):
            cursorOperationHandler(.addAbove)
        case ([.control, .shift], .keyboardDownArrow):
            cursorOperationHandler(.addBelow)
        default:
            super.keyDown(with: event)
        }
    }
}
```

Of course, you can also just customize everything. This is required if you want to use a custom `TextSystemInterface` implementation or just exert more control over how the view interacts with its cursors.

## Contributing and Collaboration

I would love to hear from you! Issues or pull requests work great. Both a [Matrix space][matrix] and [Discord][discord] are available for live help, but I have a strong bias towards answering in the form of documentation. You can also find me on [mastodon](https://mastodon.social/@mattiem).

I prefer collaboration, and would love to find ways to work together if you have a similar project.

I prefer indentation with tabs for improved accessibility. But, I'd rather you use the system you want and make a PR than hesitate because of whitespace.

By participating in this project you agree to abide by the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

[build status]: https://github.com/ChimeHQ/IBeam/actions
[build status badge]: https://github.com/ChimeHQ/IBeam/workflows/CI/badge.svg
[platforms]: https://swiftpackageindex.com/ChimeHQ/IBeam
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FChimeHQ%2FIBeam%2Fbadge%3Ftype%3Dplatforms
[documentation]: https://swiftpackageindex.com/ChimeHQ/IBeam/main/documentation
[documentation badge]: https://img.shields.io/badge/Documentation-DocC-blue
[matrix]: https://matrix.to/#/%23chimehq%3Amatrix.org
[matrix badge]: https://img.shields.io/matrix/chimehq%3Amatrix.org?label=Matrix
[discord]: https://discord.gg/esFpX6sErJ
