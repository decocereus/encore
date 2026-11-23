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

/// What fills the space above the title on Now Playing.
enum NowPlayingPane {
    case artwork, upNext, playlists
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
    var pane: NowPlayingPane = .artwork
    var searchQuery = ""
    /// Google's sign-in page is showing in the drawer.
    var signingIn = false

    var library: [Playlist] = []
    var libraryLoading = false
    var libraryError: String?
    var openPlaylist: Playlist?
    var detail: PlaylistDetail?
    var detailError: String?

    /// Playlists the current song can be added to. `choicesVideoID` is the song they were loaded for.
    var choices: [PlaylistChoice] = []
    var choicesVideoID: String?
    var choicesError: String?

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

    func loadChoices(for videoId: String) async {
        guard !videoId.isEmpty, choicesVideoID != videoId else { return }
        choicesVideoID = videoId
        choices = []
        choicesError = nil
        do {
            let loaded = try await player.playlistChoices(for: videoId)
            if choicesVideoID == videoId { choices = loaded }
        } catch {
            if choicesVideoID == videoId {
                choicesError = error.localizedDescription
                choicesVideoID = nil
            }
        }
    }

    /// Adds the song to the playlist, or takes it out if it's already there. The checkmark flips right away
    /// and flips back if YouTube Music refuses.
    func toggle(_ choice: PlaylistChoice, videoId: String) async {
        guard choicesVideoID == videoId, let index = choices.firstIndex(where: { $0.id == choice.id }) else { return }
        let include = !choice.contains
        choices[index].contains = include
        do {
            try await player.setVideo(videoId, in: choice.id, included: include)
            choicesError = nil
            if let open = openPlaylist, open.id == choice.browseID { await self.open(open) }
        } catch {
            if choicesVideoID == videoId, let i = choices.firstIndex(where: { $0.id == choice.id }) {
                choices[i].contains = !include
            }
            choicesError = error.localizedDescription
        }
    }

    func play(_ playlist: Playlist, from track: Track? = nil) {
        player.play(playlist, startingAt: track)
        tab = .nowPlaying
        pane = .artwork
    }

    func play(_ track: Track) {
        player.play(track)
        tab = .nowPlaying
        pane = .artwork
    }

    /// Account-specific state is dropped whenever the signed-in account changes.
    private func resetAccountState() {
        library = []
        libraryError = nil
        openPlaylist = nil
        detail = nil
        choices = []
        choicesVideoID = nil
        choicesError = nil
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
