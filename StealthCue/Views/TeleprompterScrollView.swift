import AppKit
import SwiftUI

/// Smooth-scrolling text, built for low CPU:
///
/// * Each paragraph is rasterised **once** (with TextKit, the same engine that measures it) into a
///   bitmap layer. Scrolling only moves a container layer, so it is pure GPU compositing — no glyph
///   drawing per frame. (`CATextLayer` was tried first; for Bangla its CoreText layout and drawing
///   disagreed and clipped the ends of lines.)
/// * Only paragraphs near the viewport have layers, so long scripts stay cheap in memory.
/// * A `CADisplayLink` exists **only while playing** (capped at 60 fps): paused = 0 % CPU.
/// * Positions are accumulated in a `Double`, so very slow speeds still move smoothly.
struct TeleprompterScrollView: NSViewRepresentable {
    var text: String
    var settings: TeleprompterSettings
    var isPlaying: Bool
    var resetToken: Int
    /// Cumulative manual-scroll requests in lines (+ = down).
    var manualScrollLines: Double = 0
    /// False for the static in-app preview.
    var autoScroll = true
    var onFinished: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PrompterView {
        let view = PrompterView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: PrompterView, context: Context) {
        context.coordinator.update(
            text: text, settings: settings, isPlaying: isPlaying && autoScroll,
            resetToken: resetToken, manualScrollLines: manualScrollLines, onFinished: onFinished)
    }

    static func dismantleNSView(_ view: PrompterView, coordinator: Coordinator) {
        coordinator.stop()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject {
        private weak var view: PrompterView?
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0

        private var position: Double = 0        // authoritative offset while playing
        private var lastAppliedY: Double = 0    // what we last wrote; differs => user scrolled
        private var wordsPerMinute: Double = 150
        private var wordCount = 1
        private var appliedKey: ContentKey?
        private var lastResetToken = 0
        private var lastManualScrollLines: Double?   // nil until first update
        private var onFinished: () -> Void = {}

        private struct ContentKey: Equatable {
            var text: String
            var fontSize: Double
            var weight: FontWeightOption
            var family: FontFamilyOption
            var lineSpacing: Double
            var alignment: TextAlignmentOption
            var color: RGBAColor
            var opacity: Double
        }

        func attach(to view: PrompterView) {
            self.view = view
        }

        func update(text: String, settings: TeleprompterSettings, isPlaying: Bool,
                    resetToken: Int, manualScrollLines: Double, onFinished: @escaping () -> Void) {
            guard let view else { return }
            self.onFinished = onFinished
            wordsPerMinute = settings.wordsPerMinute
            view.showsIndicator = settings.showScrollIndicator

            let key = ContentKey(
                text: text, fontSize: settings.fontSize, weight: settings.fontWeight,
                family: settings.fontFamily, lineSpacing: settings.lineSpacing,
                alignment: settings.textAlignment, color: settings.textColor, opacity: settings.textOpacity)
            if key != appliedKey {
                let shown = key.text.isEmpty
                    ? "Nothing to show yet.\nWrite or paste a script in the StealthCue editor."
                    : key.text
                view.setContent(
                    shown, font: settings.nsFont,
                    color: key.color.nsColor.withAlphaComponent(key.color.alpha * key.opacity),
                    alignment: key.alignment.nsAlignment, lineSpacing: key.lineSpacing)   // keeps reading fraction
                wordCount = max(shown.split(whereSeparator: \.isWhitespace).count, 1)
                position = view.offset
                lastAppliedY = view.offset
                appliedKey = key
            }

            if resetToken != lastResetToken {
                lastResetToken = resetToken
                jump(to: 0)
            }

            // Manual scrolling (↑/↓). Works while paused or playing; auto-scroll simply continues
            // from the new position.
            let lines = manualScrollLines - (lastManualScrollLines ?? manualScrollLines)
            lastManualScrollLines = manualScrollLines
            if lines != 0 {
                let lineHeight = settings.fontSize * 1.25 + settings.lineSpacing
                jump(to: view.offset + lines * lineHeight)
            }

            isPlaying ? start() : stop()
        }

        private func jump(to y: Double) {
            guard let view else { return }
            view.setOffset(y)
            position = view.offset
            lastAppliedY = view.offset
        }

        // MARK: Display link

        private func start() {
            guard displayLink == nil, let view else { return }
            if view.offset >= view.maxOffset - 1 { jump(to: 0) }   // replay from the top
            position = view.offset
            lastAppliedY = position
            lastTimestamp = 0
            let link = view.displayLink(target: self, selector: #selector(tick(_:)))
            // Reading-speed motion is smooth at 60 fps; don't burn cycles at 120 Hz on ProMotion.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
            view.isAutoScrolling = true
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            view?.isAutoScrolling = false
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let view else { return stop() }
            defer { lastTimestamp = link.timestamp }
            guard lastTimestamp > 0 else { return }
            let dt = min(link.timestamp - lastTimestamp, 0.1)

            // If the user scrolled manually (trackpad/wheel), continue from where they left it.
            if abs(view.offset - lastAppliedY) > 0.5 { position = view.offset }

            // True words-per-minute: the script's height divided by its word count gives the average
            // distance one word occupies, so it stays correct for any font size, width or language.
            let pointsPerWord = Double(view.scriptHeight) / Double(wordCount)
            position += (wordsPerMinute / 60) * pointsPerWord * dt
            let maxY = view.maxOffset
            if position >= maxY {
                view.setOffset(maxY)
                position = view.offset
                stop()
                onFinished()
                return
            }
            view.setOffset(position)
            lastAppliedY = view.offset
        }
    }
}

// MARK: - PrompterView

/// Lays a script out as paragraph layers inside a container layer that is moved to scroll.
/// Reading position is `offset` (points scrolled from the top).
final class PrompterView: NSView {
    /// One TextKit stack per paragraph. The same layout is used to measure *and* to draw, so
    /// line breaks and heights can never disagree (they did with two separate layout passes).
    private final class TextBlock {
        let storage: NSTextStorage
        let manager = NSLayoutManager()
        let container: NSTextContainer

        init(_ string: NSAttributedString, width: CGFloat) {
            storage = NSTextStorage(attributedString: string)
            container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            storage.addLayoutManager(manager)
            manager.ensureLayout(for: container)
        }

        var height: CGFloat { ceil(manager.usedRect(for: container).height) }
    }

    private struct Paragraph {
        var block: TextBlock?   // nil = blank line
        var y: CGFloat
        var height: CGFloat
    }

    private let container = CALayer()
    private let indicatorThumb = CALayer()
    private var paragraphs: [Paragraph] = []
    private var live: [Int: CALayer] = [:]   // key = paragraphIndex * tileStride + tile
    private let tileStride = 10_000
    /// Tall paragraphs are split into tiles so no single bitmap exceeds GPU texture limits.
    private let tileHeight: CGFloat = 1024
    private var contentHeight: CGFloat = 0
    private var laidOutSize: CGSize = .zero
    private var laidOutScale: CGFloat = 2
    /// Side padding shrinks on narrow windows so the text column never collapses.
    private var horizontalPadding: CGFloat { min(32, bounds.width * 0.08) }

    // Current content, kept so a resize can re-lay-out.
    private var source = ""
    private var font: NSFont = .systemFont(ofSize: 42)
    private var color: NSColor = .white
    private var alignment: NSTextAlignment = .left
    private var lineSpacing: CGFloat = 8

    /// The first line starts just below the top edge (a small margin, so there's no dead space when
    /// the overlay opens). The larger bottom inset lets the last line scroll up towards the reading
    /// area instead of stopping at the very bottom.
    private static func insets(forHeight height: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: min(24, height * 0.15), bottom: max(height * 0.4, 20))
    }
    private var topInset: CGFloat { Self.insets(forHeight: bounds.height).top }
    private var bottomInset: CGFloat { Self.insets(forHeight: bounds.height).bottom }

    private(set) var offset: Double = 0 {
        didSet { if offset != oldValue { applyOffset(); indicatorActivity() } }
    }

    /// Height of the laid-out script text (excluding the top/bottom insets).
    var scriptHeight: CGFloat { contentHeight }

    var maxOffset: Double { max(0, Double(contentHeight + topInset + bottomInset - bounds.height)) }

    /// Slim position indicator on the right edge (part of this window, so stealth mode hides it too).
    /// It fades in when the text moves and out `indicatorHideDelay` after it stops; while
    /// auto-scroll runs it stays visible.
    var showsIndicator = true {
        didSet { if showsIndicator != oldValue { updateIndicator() } }
    }

    var isAutoScrolling = false {
        didSet {
            guard isAutoScrolling != oldValue else { return }
            if isAutoScrolling { cancelIndicatorHide(); setIndicatorOpacity(1) } else { scheduleIndicatorHide() }
        }
    }

    private let indicatorHideDelay: TimeInterval = 1.5
    private var indicatorHideWork: DispatchWorkItem?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        container.anchorPoint = .zero
        container.actions = ["position": NSNull(), "bounds": NSNull()]
        layer?.addSublayer(container)
        for part in [indicatorThumb] {   // thumb only, like the rest of the app
            part.actions = ["position": NSNull(), "bounds": NSNull(), "hidden": NSNull(), "backgroundColor": NSNull()]
            part.cornerRadius = 2
            part.opacity = 0
            layer?.addSublayer(part)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func keyDown(with event: NSEvent) { nextResponder?.keyDown(with: event) }

    // MARK: Public

    /// Replaces the content; keeps the reader's place as a fraction of the script.
    func setContent(_ text: String, font: NSFont, color: NSColor, alignment: NSTextAlignment, lineSpacing: CGFloat) {
        let progress = progressFraction()
        source = text
        self.font = font
        self.color = color
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        rebuild()
        offset = min(max(progress * maxOffset, 0), maxOffset)
    }

    /// Wheel / trackpad scrolling (also works while auto-scrolling; the coordinator resyncs).
    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
        offset = min(max(offset - Double(delta), 0), maxOffset)
    }

    /// Setting the offset from outside (clamped).
    func setOffset(_ value: Double) { offset = min(max(value, 0), maxOffset) }

    override func layout() {
        super.layout()
        guard bounds.size != laidOutSize, bounds.width > 0 else { return }
        let progress = progressFraction()   // computed from the previous size
        rebuild()
        offset = min(max(progress * maxOffset, 0), maxOffset)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        // Bitmaps are rendered for a specific scale; rebuild if the screen's scale changes.
        if laidOutScale != (window?.backingScaleFactor ?? laidOutScale) { rebuild(); applyOffset() }
    }

    // MARK: Layout

    private func progressFraction() -> Double {
        // Uses the *previous* geometry, so it is valid mid-resize.
        let previousMax = max(0, Double(contentHeight + Self.insets(forHeight: laidOutSize.height).top
                                           + Self.insets(forHeight: laidOutSize.height).bottom - laidOutSize.height))
        return previousMax > 0 ? min(max(offset / previousMax, 0), 1) : 0
    }

    private func rebuild() {
        laidOutSize = bounds.size
        laidOutScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        live.values.forEach { $0.removeFromSuperlayer() }
        live.removeAll()

        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]

        let width = max(bounds.width - horizontalPadding * 2, 1)
        let gap = lineSpacing * 1.5
        let blankHeight = ceil(font.ascender - font.descender + font.leading) + lineSpacing

        var y: CGFloat = 0
        paragraphs = source.components(separatedBy: "\n").map { line in
            let paragraph: Paragraph
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                paragraph = Paragraph(block: nil, y: y, height: blankHeight)
            } else {
                let block = TextBlock(NSAttributedString(string: line, attributes: attributes), width: width)
                paragraph = Paragraph(block: block, y: y, height: block.height + 2)   // +2: rounding slack
            }
            y += paragraph.height + gap
            return paragraph
        }
        contentHeight = max(0, y - gap)
        container.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: contentHeight + topInset + bottomInset)
        applyOffset()
    }

    /// Moves the container and keeps only nearby paragraphs alive as layers.
    private func applyOffset() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.position = CGPoint(x: 0, y: -offset)

        let margin = bounds.height
        let lower = CGFloat(offset) - topInset - margin
        let upper = CGFloat(offset) - topInset + bounds.height + margin
        let width = max(bounds.width - horizontalPadding * 2, 1)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

        var wanted = Set<Int>()
        for (index, paragraph) in paragraphs.enumerated() {
            guard paragraph.block != nil else { continue }
            if paragraph.y + paragraph.height < lower { continue }
            if paragraph.y > upper { break }
            let tiles = Int(ceil(paragraph.height / tileHeight))
            for tile in 0..<tiles {
                let tileY = CGFloat(tile) * tileHeight
                let height = min(tileHeight, paragraph.height - tileY)
                if paragraph.y + tileY + height < lower || paragraph.y + tileY > upper { continue }
                let key = index * tileStride + tile
                wanted.insert(key)
                guard live[key] == nil else { continue }
                let layer = CALayer()
                layer.anchorPoint = .zero
                layer.contentsScale = scale
                layer.actions = ["position": NSNull(), "bounds": NSNull(), "contents": NSNull()]
                layer.contents = render(paragraph.block!, width: width, tileOffset: tileY, tileHeight: height, scale: scale)
                layer.frame = CGRect(x: horizontalPadding, y: topInset + paragraph.y + tileY, width: width, height: height)
                container.addSublayer(layer)
                live[key] = layer
            }
        }
        for (key, layer) in live where !wanted.contains(key) {
            layer.removeFromSuperlayer()
            live[key] = nil
        }
        updateIndicator()
        CATransaction.commit()
    }

    // MARK: Indicator visibility

    private func indicatorActivity() {
        setIndicatorOpacity(1)
        if !isAutoScrolling { scheduleIndicatorHide() }
    }

    private func scheduleIndicatorHide() {
        cancelIndicatorHide()
        let work = DispatchWorkItem { [weak self] in self?.setIndicatorOpacity(0) }
        indicatorHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + indicatorHideDelay, execute: work)
    }

    private func cancelIndicatorHide() {
        indicatorHideWork?.cancel()
        indicatorHideWork = nil
    }

    private func setIndicatorOpacity(_ value: Float) {
        guard indicatorThumb.opacity != value || indicatorThumb.animation(forKey: "opacity") != nil else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(value == 1 ? 0.12 : 0.35)
        indicatorThumb.opacity = value
        CATransaction.commit()
    }

    /// Proportional thumb (no track, like the rest of the app), positioned by reading progress. Hidden when nothing scrolls.
    private func updateIndicator() {
        let travel = maxOffset
        let hidden = !showsIndicator || travel <= 0 || bounds.height < 60
        indicatorThumb.isHidden = hidden
        guard !hidden else { return }

        let inset: CGFloat = 8, width: CGFloat = 4
        let trackHeight = bounds.height - inset * 2
        let x = bounds.width - width - 3
        let thumbHeight = min(max(trackHeight * bounds.height / (CGFloat(travel) + bounds.height), 24), trackHeight)
        let fraction = CGFloat(min(max(offset / travel, 0), 1))
        let thumbY = inset + (trackHeight - thumbHeight) * fraction

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        indicatorThumb.frame = CGRect(x: x, y: thumbY, width: width, height: thumbHeight)
        indicatorThumb.backgroundColor = color.withAlphaComponent(color.alphaComponent * 0.6).cgColor
        CATransaction.commit()
    }

    /// Draws one tile of a paragraph from its own layout (the one that measured it).
    private func render(_ block: TextBlock, width: CGFloat, tileOffset: CGFloat,
                        tileHeight: CGFloat, scale: CGFloat) -> CGImage? {
        let pixelsWide = max(Int(ceil(width * scale)), 1)
        let pixelsHigh = max(Int(ceil(tileHeight * scale)), 1)
        guard let context = CGContext(
            data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // Top-left origin, y down, in points.
        context.translateBy(x: 0, y: CGFloat(pixelsHigh))
        context.scaleBy(x: scale, y: -scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        let glyphs = block.manager.glyphRange(for: block.container)
        block.manager.drawGlyphs(forGlyphRange: glyphs, at: CGPoint(x: 0, y: -tileOffset))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}
