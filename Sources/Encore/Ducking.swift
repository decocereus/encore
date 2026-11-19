import AppKit
import CoreAudio
import Observation

struct TriggerApp: Codable, Hashable, Identifiable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
}

@MainActor
@Observable
final class DuckingSettings {
    enum Mode: String, Codable, CaseIterable {
        case chosenApps
        case anyApp
    }

    var enabled: Bool { didSet { save() } }
    /// Fraction of the user's volume kept while ducked.
    var level: Double { didSet { save() } }
    var mode: Mode { didSet { save() } }
    var apps: [TriggerApp] { didSet { save() } }

    static let hex = TriggerApp(bundleID: "anomaly.hex", name: "Hex")

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: "duck.enabled") as? Bool ?? true
        level = defaults.object(forKey: "duck.level") as? Double ?? 0.15
        mode = Mode(rawValue: defaults.string(forKey: "duck.mode") ?? "") ?? .chosenApps
        apps = defaults.data(forKey: "duck.apps").flatMap { try? JSONDecoder().decode([TriggerApp].self, from: $0) }
            ?? [Self.hex]
    }

    func add(appAt url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, !apps.contains(where: { $0.bundleID == id }) else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        apps.append(TriggerApp(bundleID: id, name: name))
    }

    func remove(_ app: TriggerApp) { apps.removeAll { $0 == app } }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "duck.enabled")
        defaults.set(level, forKey: "duck.level")
        defaults.set(mode.rawValue, forKey: "duck.mode")
        defaults.set(try? JSONEncoder().encode(apps), forKey: "duck.apps")
    }
}

/// Lowers the music while a trigger app (a dictation tool such as Hex) has the microphone open, then restores it.
@MainActor
@Observable
final class Ducker {
    private(set) var isDucked = false
    /// The app currently holding the mic, when it is a trigger.
    private(set) var activeApp: String?

    @ObservationIgnored private let player: PlayerController
    @ObservationIgnored private let settings: DuckingSettings
    @ObservationIgnored private var poll: Timer?
    @ObservationIgnored private var fade: Timer?
    @ObservationIgnored private var factor = 1.0
    @ObservationIgnored private var releaseWork: DispatchWorkItem?

    /// Always-on system listeners that would otherwise keep the music ducked forever.
    private static let ignored: Set<String> = ["com.apple.CoreSpeech", "com.apple.siri", "com.apple.assistantd", "com.apple.corespeechd"]

    init(player: PlayerController, settings: DuckingSettings) {
        self.player = player
        self.settings = settings
        poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard settings.enabled else {
            if isDucked { release(after: 0) }
            return
        }
        let listening = Self.processesUsingMicrophone().subtracting(Self.ignored)
        let trigger: String? = switch settings.mode {
        case .anyApp: listening.first { !$0.hasPrefix("com.apple.WebKit") }
        case .chosenApps: settings.apps.first { listening.contains($0.bundleID) }?.bundleID
        }

        if let trigger {
            activeApp = trigger
            releaseWork?.cancel()
            releaseWork = nil
            if !isDucked {
                isDucked = true
                animate(to: settings.level, duration: 0.25)
            }
        } else if isDucked, releaseWork == nil {
            // Hold briefly so a pause between phrases doesn't pump the music.
            release(after: 0.6)
        }
    }

    private func release(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isDucked = false
                self.activeApp = nil
                self.releaseWork = nil
                self.animate(to: 1, duration: 0.8)
            }
        }
        releaseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func animate(to target: Double, duration: TimeInterval) {
        fade?.invalidate()
        let start = factor
        let began = Date()
        fade = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                let t = min(1, Date().timeIntervalSince(began) / duration)
                let eased = 1 - pow(1 - t, 3)
                self.factor = start + (target - start) * eased
                self.player.duck(self.factor)
                if t >= 1 { timer.invalidate() }
            }
        }
    }

    // MARK: CoreAudio

    /// Bundle IDs of processes whose audio input is running right now (macOS 14+ process objects).
    static func processesUsingMicrophone() -> Set<String> {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }

        var result = Set<String>()
        for object in objects where isRunningInput(object) {
            if let id = bundleID(of: object) { result.insert(id) }
        }
        return result
    }

    private static func isRunningInput(_ object: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &running) == noErr && running != 0
    }

    private static func bundleID(of object: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr,
              let id = value?.takeRetainedValue() as String?, !id.isEmpty else { return nil }
        return id
    }
}
