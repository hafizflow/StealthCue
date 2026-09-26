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
                .padding(.horizontal, 15)
                .overlay(alignment: .topLeading) {
                    if scripts.text.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Paste or write your script here", systemImage: "text.cursor")
                                .font(.system(size: 16))
                            Text("It scrolls in a floating overlay you can read while recording.")
                                .font(.callout)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20).padding(.top, 8)
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
