import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let model: AppModel
    @AppStorage("shellGlass") private var shellGlass = ShellGlass.artwork

    var body: some View {
        @Bindable var ducking = model.ducking
        Form {
            Section("Appearance") {
                Picker("Glass", selection: $shellGlass) {
                    ForEach(ShellGlass.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("Lower music while dictating", isOn: $ducking.enabled)
                LabeledContent("Volume while dictating") {
                    HStack {
                        Slider(value: $ducking.level, in: 0.05...0.6).frame(width: 160)
                        Text("\(Int(ducking.level * 100))%").monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                }
                .disabled(!ducking.enabled)
                Picker("Lower for", selection: $ducking.mode) {
                    Text("Apps I choose").tag(DuckingSettings.Mode.chosenApps)
                    Text("Any app using the microphone").tag(DuckingSettings.Mode.anyApp)
                }
                .pickerStyle(.radioGroup)
                .disabled(!ducking.enabled)
                if ducking.mode == .chosenApps {
                    ForEach(ducking.apps) { app in
                        HStack {
                            AppIcon(bundleID: app.bundleID)
                            Text(app.name)
                            Spacer()
                            Button("Remove") { ducking.remove(app) }.controlSize(.small)
                        }
                    }
                    Button("Add App…", action: addApp)
                }
            } header: {
                Text("Dictation")
            } footer: {
                Text(model.duckedFor.map { "Music is lowered for \($0) right now." }
                     ?? "Encore watches which apps have the microphone open and lowers the music while they do.")
                    .foregroundStyle(.secondary)
            }

            Section("Accounts") {
                Picker("Active account", selection: Binding(
                    get: { model.profiles.currentID },
                    set: { id in if let profile = model.profiles.profiles.first(where: { $0.id == id }) { model.select(profile) } })) {
                    ForEach(model.profiles.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .pickerStyle(.radioGroup)
                HStack {
                    Button("Add Account…") {
                        model.addAccount()
                        model.showPanel()
                    }
                    if model.profiles.profiles.count > 1 {
                        Button("Remove “\(model.profiles.current.name)”") { model.remove(model.profiles.current) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url { model.ducking.add(appAt: url) }
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed").frame(width: 20, height: 20)
        }
    }
}
