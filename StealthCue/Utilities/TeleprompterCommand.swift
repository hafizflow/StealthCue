import AppKit

/// Actions triggered by the overlay's local keyboard shortcuts.
enum TeleprompterCommand {
    case togglePlayback, reset, faster, slower, scrollUp, scrollDown, biggerFont, smallerFont, dismiss

    /// Maps a key event to a command:
    ///
    ///     Space  Auto-scroll on / off    R  Reset
    ///     ↑ / ↓  Scroll manually         ⌥↑ / ⌥↓  Faster / slower auto-scroll
    ///     ⌘+ / ⌘-  Font size             Esc  Hide the overlay
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command), flags.isDisjoint(with: [.option, .control]) {
            switch event.charactersIgnoringModifiers {
            case "=", "+": self = .biggerFont
            case "-": self = .smallerFont
            default: return nil
            }
            return
        }

        // Arrow keys also carry .numericPad/.function; only look at the real modifiers.
        let modifiers = flags.intersection([.command, .option, .control, .shift])
        if modifiers == .option {
            switch event.keyCode {
            case 126: self = .faster      // ⌥↑
            case 125: self = .slower      // ⌥↓
            default: return nil
            }
            return
        }
        guard modifiers.isEmpty else { return nil }
        switch event.keyCode {
        case 49: self = .togglePlayback   // Space
        case 15: self = .reset            // R
        case 126: self = .scrollUp        // ↑
        case 125: self = .scrollDown      // ↓
        case 53: self = .dismiss          // Esc
        default: return nil
        }
    }
}
