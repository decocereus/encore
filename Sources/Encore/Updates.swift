import Foundation
import Observation
import Sparkle

/// Sparkle's updater, exposed as observable state for the About pane.
/// The feed URL and public key come from Info.plist (SUFeedURL, SUPublicEDKey).
@MainActor
@Observable
final class Updates {
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    private(set) var canCheck = false
    private(set) var lastChecked: Date?

    var checksAutomatically: Bool {
        get { access(keyPath: \.checksAutomatically); return updater.automaticallyChecksForUpdates }
        set { withMutation(keyPath: \.checksAutomatically) { updater.automaticallyChecksForUpdates = newValue } }
    }

    var installsAutomatically: Bool {
        get { access(keyPath: \.installsAutomatically); return updater.automaticallyDownloadsUpdates }
        set { withMutation(keyPath: \.installsAutomatically) { updater.automaticallyDownloadsUpdates = newValue } }
    }

    private var updater: SPUUpdater { controller.updater }

    init() {
        canCheck = updater.canCheckForUpdates
        lastChecked = updater.lastUpdateCheckDate
        observations = [
            updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.lastUpdateCheckDate) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.lastChecked = updater.lastUpdateCheckDate }
            },
        ]
    }

    func checkNow() { updater.checkForUpdates() }
}
