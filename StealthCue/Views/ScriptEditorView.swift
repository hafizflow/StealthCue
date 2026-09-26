import SwiftUI

/// The writing surface: a title and the script text on a quiet card, with status in the footer.
/// (Content stays opaque and calm — glass is reserved for the controls around it.)
struct ScriptEditorView: View {
    @Environment(AppState.self) private var appState
    @Binding var showPreview: Bool
    @FocusState private var editorFocused: Bool

    var body: some View {
        @Bindable var scripts = appState.scripts

        VStack(spacing: 0) {
            // Title + editing actions share one row.
            HStack(spacing: 12) {
                TextField("Script title", text: $scripts.title)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))

                GlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        Button { scripts.save() } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .keyboardShortcut("s")
                        .disabled(!scripts.isDirty)
                        .help("Save this script (⌘S)")

                        Button(role: .destructive) { scripts.clear() } label: {
                            Label("Clear", systemImage: "eraser")
                        }
                        .disabled(scripts.text.isEmpty)
                        .help("Clear the script text")

                        Button { showPreview = true } label: {
                            Label("Preview", systemImage: "eye")
                        }
                        .help("Preview how the script will look")
                    }
                    .glassButtonStyle()
                    .controlSize(.regular)
                    .labelStyle(.titleAndIcon)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            TextEditor(text: $scripts.text)
                .font(.system(size: 16))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .background(EditorScrollIndicator())
                .overlay(alignment: .topLeading) {
                    if scripts.text.isEmpty {
                        Text("Type or paste your script…")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 20).padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                if scripts.isDirty {
                    Label("Unsaved changes", systemImage: "circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .labelStyle(DotLabelStyle())
                }
                if let error = scripts.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red).lineLimit(1)
                }
                Spacer()
                Text("\(scripts.wordCount) words")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.primary.opacity(0.08)))
    }
}

/// A small coloured dot before the text (used for the "unsaved" status).
private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}


// MARK: - Auto-hiding scroll indicator for the editor

/// Gives the script editor a slim scroll indicator that appears while the text scrolls and fades
/// out 1.5 s after it stops.
///
/// `TextEditor` has no API for this and its native bar follows the system's "always show scroll
/// bars" setting, so we find its underlying `NSScrollView`, hide the native scroller, and draw our
/// own thumb as an AppKit subview of that scroll view (a SwiftUI overlay ends up behind it).
private struct EditorScrollIndicator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ helper: NSView, context: Context) {
        // The TextEditor's scroll view is laid out after us; look for it on the next runloop turn.
        DispatchQueue.main.async { [weak helper, coordinator = context.coordinator] in
            guard let helper else { return }
            coordinator.attach(near: helper)
            coordinator.hideNativeScroller()   // SwiftUI can restore it on updates
        }
    }

    final class Coordinator {
        private static let hideDelay: TimeInterval = 1.5
        /// Space between the thumb and the card's right edge.
        private static let edgeMargin: CGFloat = 3
        /// The text keeps its original left/right breathing room via an internal inset, so the
        /// scroll view itself can reach the card edge.
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
            lastOffset = found.contentView.bounds.origin.y
            update(scrolled: false)
        }

        func hideNativeScroller() {
            scrollView?.verticalScroller?.alphaValue = 0
            if let textView = scrollView?.documentView as? NSTextView,
               textView.textContainerInset.width != Self.textSideInset {
                textView.textContainerInset = NSSize(width: Self.textSideInset, height: textView.textContainerInset.height)
            }
        }

        /// Positions the thumb; flashes it only when the text actually moved.
        private func update(scrolled: Bool) {
            guard let scrollView, let document = scrollView.documentView else { return }
            hideNativeScroller()

            let visible = scrollView.contentView.bounds.height
            let content = document.frame.height
            let offset = scrollView.contentView.bounds.origin.y
            let travel = content - visible
            let moved = scrolled && abs(offset - lastOffset) > 0.5
            lastOffset = offset

            guard travel > 1 else { thumb.alphaValue = 0; return }

            let trackHeight = scrollView.bounds.height - 12
            let thumbHeight = min(max(trackHeight * visible / content, 28), trackHeight)
            let fraction = min(max(offset / travel, 0), 1)
            let fromTop = 6 + (trackHeight - thumbHeight) * fraction
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

        private static func findScrollView(near helper: NSView) -> NSScrollView? {
            var ancestor: NSView? = helper.superview
            for _ in 0..<4 {
                guard let current = ancestor else { return nil }
                if let found = firstTextScrollView(in: current) { return found }
                ancestor = current.superview
            }
            return nil
        }

        private static func firstTextScrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.documentView is NSTextView { return scroll }
            for child in view.subviews {
                if let found = firstTextScrollView(in: child) { return found }
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
