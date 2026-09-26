import AppKit
import SwiftUI

// MARK: - Color

/// A Codable sRGB color (SwiftUI's `Color` is not Codable).
struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let nearBlack = RGBAColor(red: 0.04, green: 0.04, blue: 0.05)
}

// MARK: - Font

enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case regular, medium, semibold, bold

    var id: Self { self }

    var label: String { rawValue.capitalized }

    var weight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

enum FontFamilyOption: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, monospaced, helveticaNeue, avenirNext, georgia

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        case .helveticaNeue: "Helvetica Neue"
        case .avenirNext: "Avenir Next"
        case .georgia: "Georgia"
        }
    }

    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        switch self {
        case .system:
            return base
        case .monospaced:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        case .rounded:
            return designed(base, .rounded, size)
        case .serif:
            return designed(base, .serif, size)
        case .helveticaNeue, .avenirNext, .georgia:
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: label,
                .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
            ])
            return NSFont(descriptor: descriptor, size: size) ?? base
        }
    }

    private func designed(_ base: NSFont, _ design: NSFontDescriptor.SystemDesign, _ size: CGFloat) -> NSFont {
        guard let descriptor = base.fontDescriptor.withDesign(design),
              let font = NSFont(descriptor: descriptor, size: size) else { return base }
        return font
    }
}

enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case left, center, right

    var id: Self { self }

    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}

// MARK: - Settings

/// Everything the user can tune about the overlay. Persisted as JSON in `UserDefaults`.
struct TeleprompterSettings: Codable, Equatable {
    // Text
    var fontSize: Double = 42
    var fontWeight: FontWeightOption = .semibold
    var fontFamily: FontFamilyOption = .system
    var lineSpacing: Double = 8
    var textAlignment: TextAlignmentOption = .left

    // Appearance
    var textColor: RGBAColor = .white
    var backgroundColor: RGBAColor = .nearBlack
    var textOpacity: Double = 1.0
    var backgroundOpacity: Double = 0.9
    var showScrollIndicator = true

    // Scrolling
    /// Reading speed in words per minute (what presenters actually think in).
    var wordsPerMinute: Double = 150

    // Window behaviour
    var alwaysOnTop = true
    var clickThrough = false
    var stealthMode = true
    var lockPosition = false
    var windowWidth: Double = 760
    var windowHeight: Double = 280

    init() {}

    /// Tolerant decoding: a saved blob from an older version that lacks newer keys still loads,
    /// keeping the user's tuned values and defaulting only what's missing.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ path: WritableKeyPath<TeleprompterSettings, T>, _ s: inout Self) throws {
            if let value = try c.decodeIfPresent(T.self, forKey: key) { s[keyPath: path] = value }
        }
        try read(.fontSize, \.fontSize, &self)
        try read(.fontWeight, \.fontWeight, &self)
        try read(.fontFamily, \.fontFamily, &self)
        try read(.lineSpacing, \.lineSpacing, &self)
        try read(.textAlignment, \.textAlignment, &self)
        try read(.textColor, \.textColor, &self)
        try read(.backgroundColor, \.backgroundColor, &self)
        try read(.textOpacity, \.textOpacity, &self)
        try read(.backgroundOpacity, \.backgroundOpacity, &self)
        try read(.showScrollIndicator, \.showScrollIndicator, &self)
        try read(.wordsPerMinute, \.wordsPerMinute, &self)
        try read(.alwaysOnTop, \.alwaysOnTop, &self)
        try read(.clickThrough, \.clickThrough, &self)
        try read(.stealthMode, \.stealthMode, &self)
        try read(.lockPosition, \.lockPosition, &self)
        try read(.windowWidth, \.windowWidth, &self)
        try read(.windowHeight, \.windowHeight, &self)
    }

    static let fontSizeRange: ClosedRange<Double> = 16...120
    static let lineSpacingRange: ClosedRange<Double> = 0...40
    static let wordsPerMinuteRange: ClosedRange<Double> = 60...300
    static let windowWidthRange: ClosedRange<Double> = 320...2400
    static let windowHeightRange: ClosedRange<Double> = 120...1400

    var nsFont: NSFont {
        fontFamily.font(size: fontSize, weight: fontWeight.weight)
    }

}
