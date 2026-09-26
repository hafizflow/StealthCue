import AppKit
import Observation

/// Composition root: owns the view models and the overlay window controller.
@MainActor
@Observable
final class AppState {
    let scripts: ScriptViewModel
    let teleprompter: TeleprompterViewModel
    @ObservationIgnored let overlay: TeleprompterWindowController

    init() {
        let scripts = ScriptViewModel()
        let teleprompter = TeleprompterViewModel()
        self.scripts = scripts
        self.teleprompter = teleprompter
        self.overlay = TeleprompterWindowController(model: teleprompter, script: scripts)
        overlay.onCommand = { [weak self] in self?.perform($0) }
    }

    func perform(_ command: TeleprompterCommand) {
        switch command {
        case .togglePlayback: togglePlayback()
        case .reset: teleprompter.reset()
        case .faster: teleprompter.adjustSpeed(by: 0.5)
        case .slower: teleprompter.adjustSpeed(by: -0.5)
        case .scrollUp: teleprompter.scrollManually(byLines: -1)
        case .scrollDown: teleprompter.scrollManually(byLines: 1)
        case .biggerFont: teleprompter.adjustFontSize(by: 2)
        case .smallerFont: teleprompter.adjustFontSize(by: -2)
        case .dismiss: overlay.hide()
        }
    }

    func toggleTeleprompter() { overlay.toggle() }

    /// Pressing Start with the overlay hidden shows it first.
    func togglePlayback() {
        if !teleprompter.isWindowVisible { overlay.show() }
        teleprompter.togglePlayback()
    }

    func start() {
        if !teleprompter.isWindowVisible { overlay.show() }
        teleprompter.play()
    }
}
