import Foundation
import Observation

/// Playback state + appearance/behaviour settings for the overlay.
///
/// Scroll *position* is deliberately not stored here: it changes every frame and is owned by the
/// AppKit scroll view, so playing never triggers SwiftUI updates.
@MainActor
@Observable
final class TeleprompterViewModel {
    private static let defaultsKey = "teleprompter.settings.v1"

    var settings: TeleprompterSettings {
        didSet { if settings != oldValue { persistSettings() } }
    }

    private(set) var isPlaying = false
    /// Bumped to ask the scroll view to jump back to the top.
    private(set) var resetToken = 0
    /// Cumulative manual scroll requests, in lines (+ = down). The scroll view applies the
    /// difference since it last looked, so rapid key repeats can't be lost or double-applied.
    private(set) var manualScrollLines: Double = 0
    /// Maintained by `TeleprompterWindowController`.
    var isWindowVisible = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(TeleprompterSettings.self, from: data) {
            settings = saved
        } else {
            settings = TeleprompterSettings()
        }
    }

    // MARK: Playback

    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func togglePlayback() { isPlaying.toggle() }

    func reset() {
        isPlaying = false
        resetToken &+= 1
    }

    /// Scrolls the text by whole lines, whether or not auto-scroll is running.
    func scrollManually(byLines lines: Double) { manualScrollLines += lines }

    /// Called by the scroll view when it reaches the end of the script.
    func didFinishScrolling() { isPlaying = false }

    // MARK: Adjustments

    func adjustSpeed(by delta: Double) {
        let range = TeleprompterSettings.speedRange
        settings.speed = min(max((settings.speed + delta).rounded(toPlaces: 1), range.lowerBound), range.upperBound)
    }

    func adjustFontSize(by delta: Double) {
        let range = TeleprompterSettings.fontSizeRange
        settings.fontSize = min(max(settings.fontSize + delta, range.lowerBound), range.upperBound)
    }

    // MARK: Persistence

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
