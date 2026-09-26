import SwiftUI

struct ScriptEditorView: View {
    @Environment(AppState.self) private var appState
    @Binding var showPreview: Bool

    var body: some View {
        @Bindable var scripts = appState.scripts

        VStack(alignment: .leading, spacing: 10) {
            TextField("Script title", text: $scripts.title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))

            TextEditor(text: $scripts.text)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if scripts.text.isEmpty {
                        Text("Paste or write your script here")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13).padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button("Save") { scripts.save() }
                    .keyboardShortcut("s")
                    .disabled(!scripts.isDirty)
                Button("Clear", role: .destructive) { scripts.clear() }
                    .disabled(scripts.text.isEmpty)
                Button("Preview") { showPreview = true }
                Button(appState.teleprompter.isWindowVisible ? "Hide Prompt" : "Show Prompt") {
                    appState.toggleTeleprompter()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
                if scripts.isDirty { Text("Unsaved changes").foregroundStyle(.orange) }
                Text("\(scripts.wordCount) words").foregroundStyle(.secondary)
            }
            .font(.callout)

            if let error = scripts.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
    }
}
