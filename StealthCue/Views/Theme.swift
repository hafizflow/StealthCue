import SwiftUI

/// The app's colour theme: a monochrome dark palette — dark-gray page, darker cards, and a single
/// white accent (selected pills, the primary button). No hue accent, so nothing is blue by default.
/// Values are sampled from the reference design.
enum Theme {
    /// Page background, shared by the home page and Settings. (macOS draws Settings' grouped tiles as
    /// a fixed lightening of this colour, so lowering it darkens those tiles too.)
    static let background = Color(hex: 0x232423)
    /// Cards and grouped rows.
    static let surface = Color(hex: 0x1C1C1E)
    /// Raised bars and controls that sit above the page.
    static let raised = Color(hex: 0x181B1B)
    /// Selected item on a dark surface (e.g. the selected tab pill).
    static let selectedFill = Color(hex: 0x393C3C)
    /// The one accent: white.
    static let accent = Color.white
    /// "On" state of switches and the filled part of sliders.
    static let toggleOn = Color(hex: 0xCDCDCF)
    /// Colour of the home window's top bar; Settings' top bar is set to exactly this.
    static let bar = Color(hex: 0x2B2C2B)
    static let secondaryText = Color(hex: 0x8E9096)
    static let divider = Color(hex: 0x38383B)
    /// Subtle outline for cards.
    static let hairline = Color.white.opacity(0.07)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// A card in the theme's surface colour.
    func themeCard(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Theme.surface, in: shape)
            .overlay(shape.strokeBorder(Theme.hairline))
    }

    /// Gives the window's top bar a solid colour instead of translucent glass, so it looks the same
    /// whatever is behind the window.
    @ViewBuilder
    func solidToolbar(_ color: Color) -> some View {
        if #available(macOS 15.0, *) {
            self
                .toolbarBackground(color, for: .windowToolbar)
                .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        } else {
            self.toolbarBackground(color, for: .windowToolbar)
        }
    }

    /// Applies the theme to a window's root view: dark appearance. (The light-gray accent for
    /// switches, focus rings and selection comes from the AccentColor asset; no window-wide `.tint`,
    /// which would turn every glass button white.)
    func themedWindow() -> some View {
        self.preferredColorScheme(.dark)
    }
}
