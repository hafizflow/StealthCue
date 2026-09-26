import SwiftUI

/// Root view of the floating overlay. Intentionally minimal: just the scrolling text on a
/// translucent dark panel. All controls live in the main window / menu bar so the overlay stays clean.
struct TeleprompterView: View {
    let model: TeleprompterViewModel
    let script: ScriptViewModel

    var body: some View {
        TeleprompterScrollView(
            text: script.text,
            settings: model.settings,
            isPlaying: model.isPlaying,
            resetToken: model.resetToken,
            manualScrollLines: model.manualScrollLines,
            onFinished: { model.didFinishScrolling() }
        )
        .background(model.settings.backgroundColor.color.opacity(model.settings.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .ignoresSafeArea()
    }
}
