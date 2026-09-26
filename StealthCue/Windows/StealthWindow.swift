import AppKit

/// The floating teleprompter window.
///
/// * `NSPanel` + `.nonactivatingPanel`: clicking it doesn't activate StealthCue or pull focus from
///   the app you're recording, yet it can still become key so keyboard shortcuts work once clicked.
/// * `.floating` level + `.canJoinAllSpaces`/`.fullScreenAuxiliary`: stays above normal windows,
///   on every Space, and alongside full-screen apps.
/// * Transparent, borderless-looking (hidden title bar) but still `.titled` so macOS gives us
///   reliable edge-resizing and dragging for free.
/// * Screen-capture exclusion is applied by `ScreenCaptureProtection` (see that file).
final class StealthWindow: NSPanel {
    static let minimumFrameSize = NSSize(width: 320, height: 120)

    var commandHandler: ((TeleprompterCommand) -> Void)?

    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        minSize = Self.minimumFrameSize
        title = "StealthCue Teleprompter"
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Clicking the overlay makes it the key window (so shortcuts work) without activating the app.
    /// Done here because a click that starts a background drag would otherwise never key the panel.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }

    // MARK: Local shortcuts (only active while this window is key — no global monitoring)

    override func keyDown(with event: NSEvent) {
        if let command = TeleprompterCommand(event: event) {
            commandHandler?(command)
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let command = TeleprompterCommand(event: event) {
            commandHandler?(command)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
