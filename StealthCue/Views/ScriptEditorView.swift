import SwiftUI

/// The writing surface: a title and the script text on a quiet card, with status in the footer.
/// (Content stays opaque and calm — glass is reserved for the controls around it.)
struct ScriptEditorView: View {
    @Environment(AppState.self) private var appState
    @Binding var showPreview: Bool
    @FocusState private var editorFocused: Bool
    @State private var confirmingClear = false

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
                        // No Save button: edits save automatically shortly after you stop typing.
                        Button(role: .destructive) { confirmingClear = true } label: {
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
                .autoHidingScrollIndicator()
                .overlay(alignment: .topLeading) {
                    if scripts.text.isEmpty {
                        Text("Type or paste your script…")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 19).padding(.top, 0)   // measured: lines up with the caret and typed text
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
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
        .themeCard()
        .confirmationDialog("Clear this script?", isPresented: $confirmingClear) {
            Button("Clear Script", role: .destructive) { scripts.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The text will be erased. Changes save automatically, so this can't be undone.")
        }
    }
}
