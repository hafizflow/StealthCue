# StealthCue

A native macOS teleprompter with a floating overlay designed for recordings and live presentations. Write scripts in the editor, scroll them on a borderless panel above your other apps, and optionally hide that panel from screen capture so viewers do not see your cues.

## Features

- **Script library** — Create, rename, and switch between multiple scripts; everything is stored locally as JSON in Application Support.
- **Floating teleprompter** — Auto-scrolling overlay with adjustable speed, font, colors, and opacity. Defaults to the top center of the screen for eye contact with a webcam.
- **Stealth mode** — Sets `NSWindow.sharingType = .none` so macOS can exclude the overlay from capture in apps that honor the flag. You still see the text on your display.
- **Click-through** — Let mouse events pass through the overlay when you need to interact with apps underneath.
- **Always on top** — Stays above normal windows, on every Space, and alongside full-screen apps.
- **Menu bar control** — Show/hide the overlay, start/pause, reset, and toggle stealth without bringing the editor forward.
- **Privacy by design** — App Sandbox enabled with no network entitlement; scripts never leave your Mac.

## Requirements

- macOS 14.0 or later
- Xcode 15+ (Swift 5)

## Build & run

1. Open `StealthCue.xcodeproj` in Xcode.
2. Select the **StealthCue** scheme and **My Mac** as the destination.
3. Press **⌘R** to build and run.

From the command line:

```bash
xcodebuild -scheme StealthCue -configuration Debug build
```

The project uses manual code signing with `CODE_SIGN_IDENTITY = "-"` for local development. Adjust signing in Xcode if you distribute the app.

## Usage

1. **Editor window** — Use the sidebar to manage scripts and the main area to edit text. Quick teleprompter controls live at the bottom of the window.
2. **Show teleprompter** — **Teleprompter → Show / Hide Teleprompter** (⌘⇧T), the menu bar item, or **Start** (which shows the overlay if it is hidden).
3. **While the overlay is focused** — Click the teleprompter once so it becomes the key window; shortcuts below apply only then (no global key monitoring).
4. **Settings** — **Settings…** from the menu bar or **⌘,** for fonts, window size, scrolling speed, and stealth options.

### Keyboard shortcuts

| Context | Shortcut | Action |
|--------|----------|--------|
| App menu | ⌘N | New script |
| App menu | ⌘⇧T | Show / hide teleprompter |
| App menu | ⌘↩ | Start / pause |
| App menu | ⌘⌃↑ / ⌘⌃↓ | Faster / slower scroll |
| App menu | ⌘⌥S | Toggle stealth mode |
| Overlay (key window) | Space | Start / pause auto-scroll |
| Overlay | R | Reset to top |
| Overlay | ↑ / ↓ | Scroll manually |
| Overlay | ⌥↑ / ⌥↓ | Faster / slower |
| Overlay | ⌘+ / ⌘- | Increase / decrease font size |
| Overlay | Esc | Hide overlay |

## Stealth mode — what to expect

Stealth mode is a **best-effort** request to WindowServer via a public AppKit API. It works with many screen recorders and meeting apps, but behavior depends on macOS version and how the recorder captures the display (for example CoreGraphics vs ScreenCaptureKit). It does **not** hide content from a camera pointed at your monitor or from hardware capture.

Always run a test recording with the exact software you plan to use. See **Settings → About Stealth mode** in the app and `StealthCue/Windows/ScreenCaptureProtection.swift` for implementation notes, including macOS quirks when toggling stealth on an already-visible window.

## Project structure

```
StealthCue/
├── StealthCueApp.swift          App entry, menu bar, commands
├── Models/                      Script and teleprompter settings
├── ViewModels/                  Script and teleprompter state
├── Views/                       Editor, overlay UI, settings
├── Windows/                     Overlay window, capture protection
├── Services/                    Local script persistence
└── Utilities/                   App state and command mapping
Config/
└── StealthCue.entitlements      App Sandbox (no network)
```

## Data storage

- **Scripts:** `~/Library/Containers/com.hafiz.StealthCue/Data/Library/Application Support/StealthCue/scripts.json` (sandbox path when running the signed app).
- **Teleprompter settings:** UserDefaults (JSON-encoded).
- **Overlay frame:** Autosaved via `NSWindow` frame persistence.

## License

No license file is included yet. Add one if you plan to open-source or distribute the app.
