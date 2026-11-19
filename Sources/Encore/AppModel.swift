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
    /// Browser profiles signed into YouTube, refreshed when the connect view appears.
    var browserProfiles: [BrowserProfile] = []
    var connecting: BrowserProfile.ID?
    var connectError: String?

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

    var currentSource: BrowserProfile? {
        guard let source = profiles.current.source else { return nil }
        return BrowserSession.signedInProfiles().first { $0.id == source }
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

    func refreshBrowserProfiles() {
        browserProfiles = BrowserSession.signedInProfiles()
    }

    func connect(_ source: BrowserProfile) async {
        connecting = source.id
        connectError = nil
        defer { connecting = nil }
        do {
            try await player.importSession(from: source)
            profiles.setSource(profiles.currentID, source: source.id, name: source.title)
            resetAccountState()
        } catch {
            connectError = error.localizedDescription
        }
    }

    @ObservationIgnored private var lastAutoReconnect: Date?

    /// Google rotates part of the session, so a copied sign-in eventually lapses while the browser keeps working.
    /// When that happens, import again from the same browser profile (silent once the user chose Always Allow).
    func checkSession() {
        guard player.pageLoaded, !player.state.signedIn, connecting == nil, let source = currentSource else { return }
        if let last = lastAutoReconnect, Date().timeIntervalSince(last) < 600 { return }
        lastAutoReconnect = Date()
        Task { await connect(source) }
    }

    func select(_ profile: Profile) {
        guard profile.id != profiles.currentID else { return }
        profiles.select(profile.id)
        player.load(profile: profiles.current)
        resetAccountState()
    }

    /// A new, empty account; the Library tab then offers the browser profiles to connect.
    func addAccount() {
        let profile = profiles.add(name: "New Account")
        profiles.select(profile.id)
        player.load(profile: profile)
        resetAccountState()
        expanded = true
        tab = .library
        refreshBrowserProfiles()
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
