import AppKit
import Observation
import SwiftUI

/// Creates the overlay window and keeps it in sync with `TeleprompterViewModel.settings`.
@MainActor
final class TeleprompterWindowController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "StealthCueTeleprompterFrame"

    private let model: TeleprompterViewModel
    private let script: ScriptViewModel
    private let protection = ScreenCaptureProtection()
    private var window: StealthWindow?
    private var isObserving = false

    var onCommand: ((TeleprompterCommand) -> Void)?

    init(model: TeleprompterViewModel, script: ScriptViewModel) {
        self.model = model
        self.script = script
        super.init()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        if window == nil { window = makeWindow(reusing: nil, frame: nil) }
        startObserving()
        syncWindowToSettings()
        // Front without activating StealthCue: focus stays in the app being recorded.
        window?.orderFrontRegardless()
        model.isWindowVisible = true
    }

    func hide() {
        model.pause()
        window?.orderOut(nil)
        model.isWindowVisible = false
    }

    // MARK: Window creation

    /// Builds a window with capture protection applied *before* it is ever shown.
    /// - Parameters:
    ///   - host: an existing content view to move into the new window (keeps scroll position).
    ///   - frame: the frame to adopt; otherwise the saved/default frame is used.
    private func makeWindow(reusing host: NSView?, frame: NSRect?) -> StealthWindow {
        let settings = model.settings
        let window = StealthWindow(contentSize: NSSize(width: settings.windowWidth, height: settings.windowHeight))
        window.delegate = self
        window.commandHandler = { [weak self] in self?.onCommand?($0) }

        if settings.stealthMode { protection.enable(for: window) } else { protection.disable(for: window) }

        if let host {
            window.contentView = host
        } else {
            let hosting = NSHostingView(rootView: TeleprompterView(model: model, script: script))
            hosting.sizingOptions = []   // the window, not SwiftUI, decides the size
            window.contentView = hosting
        }

        if let frame {
            window.setFrame(frame, display: false)
        } else if window.setFrameUsingName(Self.frameAutosaveName) {
            syncSizeFromWindow(window)
        } else {
            positionAtTopCenter(window)
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        return window
    }

    /// Stealth was switched back on: `.none` can't be reliably re-applied to a live window (see
    /// `ScreenCaptureProtection`), so swap in a fresh one that is protected before it is shown.
    private func replaceWindow() {
        guard let old = window else { return }
        let wasVisible = old.isVisible
        let frame = old.frame
        let host = old.contentView
        old.delegate = nil
        old.setFrameAutosaveName("")
        old.contentView = nil
        protection.forget(old)

        let replacement = makeWindow(reusing: host, frame: frame)
        window = replacement
        if wasVisible { replacement.orderFrontRegardless() }
        old.orderOut(nil)
        old.close()
    }

    /// Top-centre of the main screen puts the script right under a webcam — good for eye contact.
    private func positionAtTopCenter(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.maxY - size.height - 12))
    }

    // MARK: Settings → window

    /// Re-arms itself after every change (the Observation framework's one-shot pattern).
    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        observeSettings()
    }

    private func observeSettings() {
        withObservationTracking {
            syncWindowToSettings()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSettings() }
        }
    }

    private func syncWindowToSettings() {
        guard let window else { return }
        let settings = model.settings

        // Stealth: exclude from screen capture. Turning it ON for a window that has been visible
        // to capture needs a fresh window; turning it OFF can be done in place.
        if settings.stealthMode, !protection.isEnabled(for: window) {
            replaceWindow()
        } else if !settings.stealthMode, protection.isEnabled(for: window) {
            protection.disable(for: window)
        }
        guard let window = self.window else { return }

        if window.isFloatingPanel != settings.alwaysOnTop { window.isFloatingPanel = settings.alwaysOnTop }
        let level: NSWindow.Level = settings.alwaysOnTop ? .floating : .normal
        if window.level != level { window.level = level }

        // Click-through: mouse events fall to whatever is underneath the overlay.
        if window.ignoresMouseEvents != settings.clickThrough { window.ignoresMouseEvents = settings.clickThrough }

        // Lock position.
        let movable = !settings.lockPosition
        if window.isMovable != movable { window.isMovable = movable }
        if window.isMovableByWindowBackground != movable { window.isMovableByWindowBackground = movable }

        // Size (keep the top-left corner fixed while resizing).
        let current = window.contentRect(forFrameRect: window.frame).size
        if abs(current.width - settings.windowWidth) > 0.5 || abs(current.height - settings.windowHeight) > 0.5 {
            var frame = window.frame
            let newSize = window.frameRect(
                forContentRect: NSRect(x: 0, y: 0, width: settings.windowWidth, height: settings.windowHeight)).size
            frame.origin.y += frame.height - newSize.height
            frame.size = newSize
            window.setFrame(frame, display: true)
        }
    }

    // MARK: Window → settings

    /// `minSize` alone wasn't honoured by drag-resizing (the overlay could be shrunk to ~150 pt,
    /// where text has no room to wrap), so clamp explicitly.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: max(frameSize.width, StealthWindow.minimumFrameSize.width),
               height: max(frameSize.height, StealthWindow.minimumFrameSize.height))
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? StealthWindow else { return }
        syncSizeFromWindow(window)
    }

    private func syncSizeFromWindow(_ window: NSWindow) {
        let size = window.contentRect(forFrameRect: window.frame).size
        if abs(model.settings.windowWidth - size.width) > 0.5 { model.settings.windowWidth = size.width }
        if abs(model.settings.windowHeight - size.height) > 0.5 { model.settings.windowHeight = size.height }
    }
}
