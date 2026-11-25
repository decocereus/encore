import AppKit
import Observation
import WebKit

enum DrawerTab: String, CaseIterable, Identifiable {
    case nowPlaying, library
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .library: "square.stack"
        }
    }
}

/// What fills the space above the title on Now Playing.
enum NowPlayingPane {
    case artwork, upNext
}

/// The New Playlist and Edit Details form that replaces the library list.
struct PlaylistForm: Equatable {
    enum Mode: Equatable {
        /// `seed` is the song the new playlist starts with, if any.
        case create(seed: Track?)
        case edit(Playlist)
    }

    var mode: Mode
    var name: String
    var privacy: PlaylistPrivacy
    var includeSeed = true
    var saving = false
    var error: String?
}

/// A short message over the bottom of the drawer, with an optional Undo.
struct Toast: Identifiable {
    let id = UUID()
    var text: String
    var undo: (() -> Void)?
}

/// A song removed from a playlist that hasn't been sent yet, so Undo can cancel it.
struct PendingRemoval: Equatable {
    let id = UUID()
    let track: Track
    let playlist: Playlist
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
    var form: PlaylistForm?
    var pendingRemoval: PendingRemoval?
    var toast: Toast?

    /// The playlists the account can save songs to, and the songs in each, keyed by playlist ID.
    /// YouTube Music no longer says which playlists hold a song, so Encore keeps this index itself.
    var editablePlaylists: [PlaylistChoice] = []
    var membership: [String: Set<String>] = [:]
    var playlistsLoaded = false
    var playlistsError: String?
    /// When every playlist was last read, so changes made in other apps are picked up now and then.
    @ObservationIgnored private var indexedAt: Date?
    var indexIsStale: Bool { indexedAt.map { Date().timeIntervalSince($0) > 600 } ?? false }
    /// Ratings fetched for the playing song or set in Encore. They win over what lists reported when they loaded.
    var knownLikes: [String: LikeStatus] = [:]

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

    /// The playing song as a list track, for menus and the New Playlist form.
    var currentTrack: Track? {
        let state = player.state
        guard state.hasTrack, !state.videoId.isEmpty else { return nil }
        return Track(videoId: state.videoId, title: state.title, subtitle: state.artist, thumb: state.artURL)
    }


    // MARK: Library

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
        if openPlaylist != playlist { detail = nil }
        openPlaylist = playlist
        detailError = nil
        do {
            let loaded = try await player.playlist(playlist)
            if openPlaylist == playlist { detail = loaded }
        } catch {
            if openPlaylist == playlist { detailError = error.localizedDescription }
        }
    }

    /// Reloads the open playlist if it's the given one, after a change made somewhere else in the panel.
    private func refreshDetail(ifShowing browseID: String) async {
        if let open = openPlaylist, open.id == browseID { await self.open(open) }
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

    // MARK: Saving to playlists

    /// Loads the editable playlists, then indexes the songs of any not indexed yet, a few playlists at a time.
    /// Encore keeps the index current as it adds and removes songs; `reindex` reads every playlist again
    /// to pick up changes made elsewhere.
    func loadPlaylists(force: Bool = false, reindex: Bool = false) async {
        guard force || reindex || !playlistsLoaded else { return }
        do {
            var playlists = try await player.editablePlaylists()
            // A playlist created moments ago can be missing from YouTube Music's list for a while.
            for created in editablePlaylists where membership[created.id] != nil && !playlists.contains(where: { $0.id == created.id }) {
                playlists.insert(created, at: 0)
            }
            editablePlaylists = playlists
            playlistsError = nil
            playlistsLoaded = true
            if reindex || indexedAt == nil { indexedAt = Date() }
            let known = reindex ? [] : Set(membership.keys)
            let pending = playlists.map(\.id).filter { !known.contains($0) }
            let player = self.player
            await withTaskGroup(of: (String, Set<String>?).self) { group in
                var queue = pending[...]
                func next() {
                    guard let id = queue.popFirst() else { return }
                    group.addTask { (id, try? await player.videoIds(inPlaylist: id)) }
                }
                for _ in 0..<4 { next() }
                for await (id, ids) in group {
                    if let ids { membership[id] = ids }
                    next()
                }
            }
        } catch {
            playlistsError = error.localizedDescription
        }
    }

    func contains(_ videoId: String, in choice: PlaylistChoice) -> Bool {
        membership[choice.id]?.contains(videoId) ?? false
    }

    /// The account's playlists that hold the song.
    func playlists(containing videoId: String) -> [PlaylistChoice] {
        editablePlaylists.filter { contains(videoId, in: $0) }
    }

    /// Adds a song to a playlist or takes it out. The checkmark flips right away and flips back if YouTube Music refuses.
    func setSaved(_ track: Track, in choice: PlaylistChoice, _ include: Bool) async {
        func apply(_ on: Bool) {
            if on { membership[choice.id, default: []].insert(track.videoId) } else { membership[choice.id]?.remove(track.videoId) }
        }
        apply(include)
        do {
            try await player.setVideo(track.videoId, in: choice.id, included: include)
            show(include ? "Saved to \(choice.title)" : "Removed from \(choice.title)")
            await refreshDetail(ifShowing: choice.browseID)
            await loadLibrary(force: true)
        } catch {
            apply(!include)
            show(error.localizedDescription)
        }
    }

    // MARK: Likes

    func likeStatus(of track: Track, in playlist: Playlist? = nil) -> LikeStatus {
        if let status = knownLikes[track.videoId] ?? track.likeStatus { return status }
        return playlist?.isLikedMusic == true ? .like : .indifferent
    }

    /// Fetches the playing song's rating once; after that Encore's own changes keep it current.
    func loadLikeStatus(for videoId: String) async {
        guard !videoId.isEmpty, knownLikes[videoId] == nil else { return }
        if let status = try? await player.likeStatus(of: videoId), knownLikes[videoId] == nil {
            knownLikes[videoId] = status
        }
    }

    /// Sets a rating. Choosing the rating a song already has clears it, the way YouTube Music's buttons work.
    /// Disliking the playing song skips it, as YouTube Music does.
    func rate(_ track: Track, _ status: LikeStatus, in playlist: Playlist? = nil) async {
        let old = likeStatus(of: track, in: playlist)
        let new = old == status ? LikeStatus.indifferent : status
        knownLikes[track.videoId] = new
        do {
            try await player.rate(track.videoId, new)
            if new == .dislike, old != .dislike {
                show("Disliked \(track.title)")
                if track.videoId == player.state.videoId { player.next() }
            }
            if openPlaylist?.isLikedMusic == true, old == .like || new == .like {
                await refreshDetail(ifShowing: "VLLM")
            }
        } catch {
            knownLikes[track.videoId] = old
            show(error.localizedDescription)
        }
    }

    // MARK: Creating and editing playlists

    func startNewPlaylist(with seed: Track?) {
        guard player.state.signedIn else { return signIn() }
        form = PlaylistForm(mode: .create(seed: seed), name: "", privacy: .private)
        openPlaylist = nil
        expanded = true
        tab = .library
    }

    func startEditing(_ detail: PlaylistDetail) {
        form = PlaylistForm(mode: .edit(detail.playlist), name: detail.playlist.title, privacy: detail.privacy ?? .private)
        expanded = true
        tab = .library
    }

    func submitForm() async {
        guard var draft = form, !draft.saving else { return }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        draft.saving = true
        draft.error = nil
        form = draft
        do {
            switch draft.mode {
            case .create(let seed):
                let videoIds = draft.includeSeed ? [seed?.videoId].compactMap(\.self) : []
                let id = try await player.createPlaylist(title: name, privacy: draft.privacy, videoIds: videoIds)
                form = nil
                show("Created \(name)")
                await loadLibrary(force: true)
                membership[id] = draft.includeSeed ? Set([seed?.videoId].compactMap { $0 }) : []
                if !editablePlaylists.contains(where: { $0.id == id }) {
                    editablePlaylists.insert(PlaylistChoice(id: id, title: name), at: 0)
                }
                await loadPlaylists(force: true)
                let created = library.first { $0.id == "VL" + id } ?? Playlist(id: "VL" + id, title: name, subtitle: "", thumb: nil)
                // A new playlist can take a moment before YouTube Music returns it.
                for _ in 0..<5 {
                    await open(created)
                    if openPlaylist != created || detail?.editable == true { break }
                    try? await Task.sleep(for: .seconds(1))
                }
            case .edit(let playlist):
                try await player.editPlaylist(playlist.playlistID, title: name, privacy: draft.privacy)
                form = nil
                show("Saved changes")
                if let i = editablePlaylists.firstIndex(where: { $0.id == playlist.playlistID }) { editablePlaylists[i].title = name }
                await loadLibrary(force: true)
                await open(library.first { $0.id == playlist.id } ?? playlist)
            }
        } catch {
            form?.saving = false
            form?.error = error.localizedDescription
        }
    }

    func delete(_ playlist: Playlist) async {
        do {
            try await player.deletePlaylist(playlist.playlistID)
            if openPlaylist?.id == playlist.id { openPlaylist = nil; detail = nil }
            library.removeAll { $0.id == playlist.id }
            show("Deleted \(playlist.title)")
            membership[playlist.playlistID] = nil
            editablePlaylists.removeAll { $0.id == playlist.playlistID }
            await loadLibrary(force: true)
        } catch {
            show(error.localizedDescription)
        }
    }

    // MARK: Removing songs

    /// Hides the song at once and sends the removal a few seconds later, unless Undo is pressed first.
    /// In Liked Songs, removing a song unlikes it.
    func remove(_ track: Track, from playlist: Playlist) {
        if let earlier = pendingRemoval { Task { await commit(earlier) } }
        let pending = PendingRemoval(track: track, playlist: playlist)
        pendingRemoval = pending
        show("Removed \(track.title)") { [weak self] in
            if self?.pendingRemoval == pending { self?.pendingRemoval = nil }
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if pendingRemoval == pending { await commit(pending) }
        }
    }

    private func commit(_ pending: PendingRemoval) async {
        let track = pending.track
        if openPlaylist?.id == pending.playlist.id {
            detail?.tracks.removeAll { $0.videoId == track.videoId }
        }
        if pendingRemoval == pending { pendingRemoval = nil }
        do {
            if pending.playlist.isLikedMusic {
                knownLikes[track.videoId] = .indifferent
                try await player.rate(track.videoId, .indifferent)
            } else {
                try await player.setVideo(track.videoId, in: pending.playlist.playlistID, included: false)
                membership[pending.playlist.playlistID]?.remove(track.videoId)
            }
        } catch {
            show("Couldn't remove \(track.title): \(error.localizedDescription)")
            await refreshDetail(ifShowing: pending.playlist.id)
        }
    }

    // MARK: Toast

    func show(_ text: String, undo: (() -> Void)? = nil) {
        let toast = Toast(text: text, undo: undo)
        self.toast = toast
        Task {
            try? await Task.sleep(for: .seconds(4))
            if self.toast?.id == toast.id { self.toast = nil }
        }
    }

    /// Account-specific state is dropped whenever the signed-in account changes.
    private func resetAccountState() {
        library = []
        libraryError = nil
        openPlaylist = nil
        detail = nil
        editablePlaylists = []
        membership = [:]
        indexedAt = nil
        playlistsLoaded = false
        playlistsError = nil
        knownLikes = [:]
        form = nil
        pendingRemoval = nil
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
