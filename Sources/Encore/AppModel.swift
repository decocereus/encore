import AppKit
import Observation
import WebKit

enum DrawerTab: String, CaseIterable, Identifiable {
    case nowPlaying, library, search
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .library: "Library"
        case .search: "Search"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .library: "square.stack"
        case .search: "magnifyingglass"
        }
    }
}

/// UI state and account actions shared by the panel's views.
@MainActor
@Observable
final class AppModel {
    let player: PlayerController
    let profiles: ProfileStore
    let ducking: DuckingSettings
    let ducker: Ducker

    var expanded = false
    var tab: DrawerTab = .nowPlaying
    var showQueue = false
    var searchQuery = ""
    /// Google's sign-in page is showing in the drawer.
    var signingIn = false

    var library: [Playlist] = []
    var libraryLoading = false
    var libraryError: String?
    var openPlaylist: Playlist?
    var detail: PlaylistDetail?
    var detailError: String?

    @ObservationIgnored var openSettings: () -> Void = {}
    @ObservationIgnored var hidePanel: () -> Void = {}
    @ObservationIgnored var showPanel: () -> Void = {}

    init(player: PlayerController, profiles: ProfileStore, ducking: DuckingSettings, ducker: Ducker) {
        self.player = player
        self.profiles = profiles
        self.ducking = ducking
        self.ducker = ducker
    }

    /// Display name of the app the music is ducked for.
    var duckedFor: String? {
        guard ducker.isDucked, let id = ducker.activeApp else { return nil }
        return ducking.apps.first { $0.bundleID == id }?.name
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
            ?? "dictation"
    }

    func loadLibrary(force: Bool = false) async {
        guard force || library.isEmpty, !libraryLoading else { return }
        libraryLoading = true
        defer { libraryLoading = false }
        do {
            library = try await player.library()
            libraryError = nil
        } catch {
            libraryError = error.localizedDescription
        }
    }

    func open(_ playlist: Playlist) async {
        openPlaylist = playlist
        detail = nil
        detailError = nil
        do {
            let loaded = try await player.playlist(playlist)
            if openPlaylist == playlist { detail = loaded }
        } catch {
            if openPlaylist == playlist { detailError = error.localizedDescription }
        }
    }

    func play(_ playlist: Playlist, from track: Track? = nil) {
        player.play(playlist, startingAt: track)
        tab = .nowPlaying
        showQueue = false
    }

    func play(_ track: Track) {
        player.play(track)
        tab = .nowPlaying
        showQueue = false
    }

    /// Account-specific state is dropped whenever the signed-in account changes.
    private func resetAccountState() {
        library = []
        libraryError = nil
        openPlaylist = nil
        detail = nil
    }

    func signIn() {
        expanded = true
        signingIn = true
    }

    /// Google's sign-in landed back on YouTube Music: reload the player with the new session and name the account.
    func finishSignIn() {
        signingIn = false
        resetAccountState()
        player.goHome()
        tab = .library
        Task {
            for _ in 0..<40 where !(player.pageLoaded && player.state.signedIn) {
                try? await Task.sleep(for: .milliseconds(250))
            }
            if let name = try? await player.accountName(), !name.isEmpty {
                profiles.rename(profiles.currentID, to: name)
            }
        }
    }

    func select(_ profile: Profile) {
        guard profile.id != profiles.currentID else { return }
        signingIn = false
        profiles.select(profile.id)
        player.load(profile: profiles.current)
        resetAccountState()
    }

    /// A new, empty account that goes straight to Google's sign-in.
    func addAccount() {
        let profile = profiles.add(name: "New Account")
        profiles.select(profile.id)
        player.load(profile: profile)
        resetAccountState()
        tab = .library
        signIn()
    }

    func remove(_ profile: Profile) {
        let wasCurrent = profile.id == profiles.currentID
        profiles.remove(profile.id)
        if wasCurrent {
            player.load(profile: profiles.current)
            resetAccountState()
        }
        // The web view using the store has to be gone before it can be removed.
        Task {
            try? await Task.sleep(for: .seconds(1))
            try? await WKWebsiteDataStore.remove(forIdentifier: profile.id)
        }
    }
}
