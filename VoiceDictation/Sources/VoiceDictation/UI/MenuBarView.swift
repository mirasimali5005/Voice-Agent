import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.isRecording {
                Label("Recording...", systemImage: "record.circle")
                    .foregroundColor(.red)
            } else {
                Label("Ready", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
            }

            Divider()

            Button("Open Voice Agent") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Voice Agent") || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .keyboardShortcut("o")

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")

            Divider()

            // MARK: Mode Picker

            Text("Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(DictationMode.allCases) { mode in
                Button {
                    appState.dictationMode = mode.rawValue
                } label: {
                    HStack {
                        Text(mode.rawValue.capitalized)
                        Spacer()
                        if appState.currentMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
