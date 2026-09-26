import AppKit
import SwiftUI

// MARK: - The app's scroll indicator
//
// One indicator for every scrolling area in the app: a slim thumb at the edge that fades in while the
// content scrolls and fades out 1.5 s after it stops. It never depends on the system's "Show scroll
// bars" setting, and it is only drawn when the content is taller than the area.

extension View {
    /// Replaces the native scroll bar of the scroll view inside this view with the app's indicator.
    /// Apply it to a `List`, `Form`, `TextEditor` or `ScrollView`.
    func autoHidingScrollIndicator() -> some View {
        background(AutoHidingScrollIndicator())
    }
}

/// SwiftUI has no API for this, and the native bar follows the system "always show scroll bars" setting
/// (SwiftUI even restores it on updates), so we find the underlying `NSScrollView`, make the native
/// scroller invisible, and draw our own thumb as an AppKit subview of that scroll view (a SwiftUI overlay
/// ends up behind it).
private struct AutoHidingScrollIndicator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ helper: NSView, context: Context) {
        // The scroll view is laid out after us; look for it on the next runloop turn.
        DispatchQueue.main.async { [weak helper, coordinator = context.coordinator] in
            guard let helper else { return }
            coordinator.attach(near: helper)
            coordinator.hideNativeScroller()   // SwiftUI can restore it on updates
        }
    }

    final class Coordinator {
        private static let hideDelay: TimeInterval = 1.5
        /// Space between the thumb and the right edge.
        private static let edgeMargin: CGFloat = 3
        /// Text views keep their original left/right breathing room via an internal inset, so the scroll
        /// view itself can reach the card edge (used by the script editor).
        private static let textSideInset: CGFloat = 15

        private weak var scrollView: NSScrollView?
        private let thumb = ThumbView()
        private var tokens: [NSObjectProtocol] = []
        private var lastOffset: CGFloat = 0
        private var hideWork: DispatchWorkItem?

        deinit {
            tokens.forEach(NotificationCenter.default.removeObserver)
            hideWork?.cancel()
            thumb.removeFromSuperview()
        }

        func attach(near helper: NSView) {
            guard let found = Self.findScrollView(near: helper), found !== scrollView else { return }
            tokens.forEach(NotificationCenter.default.removeObserver)
            scrollView = found
            found.contentView.postsBoundsChangedNotifications = true
            found.documentView?.postsFrameChangedNotifications = true
            found.addSubview(thumb)   // above the clip view, so it can't be occluded

            let center = NotificationCenter.default
            tokens = [
                center.addObserver(forName: NSView.boundsDidChangeNotification, object: found.contentView, queue: .main) { [weak self] _ in self?.update(scrolled: true) },
                center.addObserver(forName: NSView.frameDidChangeNotification, object: found.documentView, queue: .main) { [weak self] _ in self?.update(scrolled: false) },
                center.addObserver(forName: NSView.frameDidChangeNotification, object: found, queue: .main) { [weak self] _ in self?.update(scrolled: false) },
            ]
            found.postsFrameChangedNotifications = true
            hideNativeScroller()
            lastOffset = Self.scrolledDistance(of: found)
            update(scrolled: false)
        }

        func hideNativeScroller() {
            guard let scrollView else { return }
            scrollView.verticalScroller?.alphaValue = 0
            if let textView = scrollView.documentView as? NSTextView,
               textView.textContainerInset.width != Self.textSideInset {
                textView.textContainerInset = NSSize(width: Self.textSideInset, height: textView.textContainerInset.height)
            }
        }

        /// Distance scrolled from the top, measured inside any content insets (a list under a search bar
        /// or toolbar starts at a negative clip-view origin).
        private static func scrolledDistance(of scrollView: NSScrollView) -> CGFloat {
            scrollView.contentView.bounds.origin.y + scrollView.contentInsets.top
        }

        /// Positions the thumb; flashes it only when the content actually moved.
        private func update(scrolled: Bool) {
            guard let scrollView, let document = scrollView.documentView else { return }
            hideNativeScroller()

            let insets = scrollView.contentInsets
            let visible = scrollView.contentView.bounds.height - insets.top - insets.bottom
            let content = document.frame.height
            let offset = Self.scrolledDistance(of: scrollView)
            let travel = content - visible
            let moved = scrolled && abs(offset - lastOffset) > 0.5
            lastOffset = offset

            guard travel > 1, visible > 0 else { thumb.alphaValue = 0; return }

            let trackHeight = scrollView.bounds.height - insets.top - insets.bottom - 12
            let thumbHeight = min(max(trackHeight * visible / content, 28), trackHeight)
            let fraction = min(max(offset / travel, 0), 1)
            let fromTop = insets.top + 6 + (trackHeight - thumbHeight) * fraction
            let y = scrollView.isFlipped ? fromTop : scrollView.bounds.height - fromTop - thumbHeight
            thumb.frame = CGRect(x: scrollView.bounds.width - ThumbView.width - Self.edgeMargin, y: y,
                                 width: ThumbView.width, height: thumbHeight)

            if moved { flash() }
        }

        private func flash() {
            setThumb(alpha: 1, duration: 0.12)
            hideWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.setThumb(alpha: 0, duration: 0.35) }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: work)
        }

        private func setThumb(alpha: CGFloat, duration: TimeInterval) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                thumb.animator().alphaValue = alpha
            }
        }

        /// The nearest scroll view: look at the helper's siblings first, then one level further out.
        private static func findScrollView(near helper: NSView) -> NSScrollView? {
            var ancestor: NSView? = helper.superview
            for _ in 0..<4 {
                guard let current = ancestor else { return nil }
                if let found = firstScrollView(in: current) { return found }
                ancestor = current.superview
            }
            return nil
        }

        private static func firstScrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.documentView != nil { return scroll }
            for child in view.subviews {
                if let found = firstScrollView(in: child) { return found }
            }
            return nil
        }
    }

    /// The thumb itself: a small rounded bar that ignores the mouse.
    final class ThumbView: NSView {
        static let width: CGFloat = 4

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            alphaValue = 0
            layer?.cornerRadius = Self.width / 2
            updateColor()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not used") }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateColor()
        }

        private func updateColor() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.4).cgColor
            }
        }
    }
}
