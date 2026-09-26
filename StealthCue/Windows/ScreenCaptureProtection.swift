import AppKit

/// Excludes an `NSWindow` from screen capture where the OS honors it.
///
/// ## The API
/// `NSWindow.sharingType` (public AppKit API, no private symbols, no entitlement, no permission):
///
/// | value        | meaning                                                              |
/// |--------------|----------------------------------------------------------------------|
/// | `.none`      | Window contents may not be read by other processes. **Stealth on.**  |
/// | `.readOnly`  | Default. Other processes may capture the window's pixels.            |
/// | `.readWrite` | Other processes may also draw into it. Never used here.              |
///
/// The window is still composited to *your* display, so you keep seeing it.
///
/// ## What this does and does not guarantee
/// This is a *request* to WindowServer, honored by the capture paths Apple's compositor
/// applies it to. Nothing here can stop a camera pointed at the screen or an HDMI capture card,
/// and Apple does not document which capture stacks honor it or promise it across OS releases.
/// Treat it as best-effort and **test your recorder**.
///
/// ## Observed quirk: `.none` can't be re-applied to a live window
/// On macOS 26.3 (when the app is launched normally, i.e. through LaunchServices) a window that
/// has been moved *off* `.none` could not be moved back to `.none`: `NSWindow.sharingType` reads
/// back `.none` regardless, the later `.none` assignment is treated as "no change", and the
/// window server stays at `.readOnly`. Setting `.none` on a **fresh window before it is first
/// shown** always worked. So the rule this class encodes is:
///
/// * call `enable(for:)` before the window is first ordered on screen, and
/// * to turn stealth back on later, use a new window (`TeleprompterWindowController` does).
///
/// Because the getter can't be trusted, we record what we last asked for ourselves.
@MainActor
final class ScreenCaptureProtection {
    private var requested: [ObjectIdentifier: Bool] = [:]

    func enable(for window: NSWindow) {
        window.sharingType = .none
        requested[ObjectIdentifier(window)] = true
    }

    func disable(for window: NSWindow) {
        window.sharingType = .readOnly
        requested[ObjectIdentifier(window)] = false
    }

    /// What we last requested for this window (not `NSWindow.sharingType`, see above).
    func isEnabled(for window: NSWindow) -> Bool {
        requested[ObjectIdentifier(window)] ?? false
    }

    /// Call when a window is discarded so a recycled object address can't inherit its state.
    func forget(_ window: NSWindow) {
        requested[ObjectIdentifier(window)] = nil
    }
}
