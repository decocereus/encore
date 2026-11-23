import AppKit
import SwiftUI

struct AboutSettings: View {
    let updates: Updates

    var body: some View {
        @Bindable var updates = updates
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("Encore")
                        .font(.system(size: 26, weight: .bold))
                    Text("Version \(AppInfo.version) (\(AppInfo.build))")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("YouTube Music, in your menu bar.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $updates.checksAutomatically)
                Toggle(isOn: $updates.installsAutomatically) {
                    Text("Download and install updates automatically")
                    Text("Installs when you quit Encore.")
                }
                .disabled(!updates.checksAutomatically)
                HStack {
                    Button("Check for Updates…", action: updates.checkNow)
                        .disabled(!updates.canCheck)
                    Spacer()
                    Text(updates.lastChecked.map { "Last checked \($0.formatted(date: .numeric, time: .shortened))" }
                         ?? "Never checked")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                FeedbackLink(title: "Report a bug", kind: .bug)
                FeedbackLink(title: "Suggest a feature", kind: .feature)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Opens a new GitHub issue with your Encore and macOS versions filled in. Nothing is sent until you submit it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Encore is an unofficial client. It isn't affiliated with or endorsed by Google or YouTube.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link(destination: AppInfo.repository) {
                    LabeledContent("Source code") { Label("GitHub", systemImage: "arrow.up.right").labelStyle(TrailingIcon()) }
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FeedbackLink: View {
    enum Kind { case bug, feature }
    let title: String
    let kind: Kind

    var body: some View {
        Link(destination: url) {
            LabeledContent(title) { Label("GitHub Issues", systemImage: "arrow.up.right").labelStyle(TrailingIcon()) }
        }
        .buttonStyle(.plain)
    }

    private var url: URL {
        let environment = "Encore \(AppInfo.version) (\(AppInfo.build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        let body = switch kind {
        case .bug: "**What happened?**\n\n\n**What did you expect?**\n\n\n**Steps to reproduce**\n1. \n\n---\n\(environment)"
        case .feature: "**What would you like Encore to do?**\n\n\n**Why?**\n\n\n---\n\(environment)"
        }
        var components = URLComponents(url: AppInfo.repository.appending(path: "issues/new"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "labels", value: kind == .bug ? "bug" : "enhancement"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url!
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
        .foregroundStyle(.secondary)
    }
}

enum AppInfo {
    static let repository = URL(string: "https://github.com/decocereus/encore")!
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
}
