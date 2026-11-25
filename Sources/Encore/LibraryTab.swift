import SwiftUI

/// Your playlists and YouTube Music search in one tab. The field on top filters playlists and searches songs.
struct LibraryTab: View {
    let model: AppModel

    var body: some View {
        let player = model.player
        Group {
            if !player.pageLoaded {
                ProgressView().frame(maxHeight: .infinity)
            } else if model.form != nil {
                PlaylistFormView(model: model)
            } else if player.state.signedIn, let playlist = model.openPlaylist {
                PlaylistView(model: model, playlist: playlist)
            } else {
                VStack(spacing: 8) {
                    SearchField(model: model)
                    if model.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                        if player.state.signedIn { PlaylistList(model: model) } else { ConnectView(model: model) }
                    } else {
                        SearchResults(model: model)
                    }
                }
            }
        }
        .task(id: "\(model.profiles.currentID)-\(player.state.signedIn)") {
            guard player.state.signedIn else { return }
            await model.loadLibrary()
            if model.indexIsStale { await model.loadPlaylists(reindex: true) }
        }
    }
}

private struct SearchField: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(model.player.state.signedIn ? "Your library and YouTube Music" : "Search YouTube Music",
                      text: $model.searchQuery)
                .textFieldStyle(.plain)
                .focused($focused)
            if !model.searchQuery.isEmpty {
                Button { model.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.primary.opacity(0.08), in: .capsule)
        .padding(.horizontal, 16)
        .onAppear { focused = true }
    }
}

// MARK: - Playlists

private struct PlaylistList: View {
    let model: AppModel

    var body: some View {
        if model.library.isEmpty, model.libraryLoading || model.libraryError != nil {
            VStack(spacing: 10) {
                if let error = model.libraryError {
                    Text("Couldn't load your library").font(.headline)
                    Text(error).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try Again") { Task { await model.loadLibrary(force: true) } }
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 32)
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    NewPlaylistRow { model.startNewPlaylist(with: nil) }
                    let liked = model.library.filter(\.isLikedMusic)
                    let others = model.library.filter { !$0.isLikedMusic }
                    ForEach(liked) { playlist in
                        PlaylistRow(model: model, playlist: playlist, subtitle: "Your liked songs")
                    }
                    if !others.isEmpty {
                        SectionLabel("Playlists")
                        ForEach(others) { playlist in
                            PlaylistRow(model: model, playlist: playlist, subtitle: playlist.subtitle)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .fadingEdges()
            .refreshable { await model.loadLibrary(force: true) }
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

private struct NewPlaylistRow: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.primary.opacity(0.06))
                    .strokeBorder(.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .overlay { Image(systemName: "plus").font(.title3).foregroundStyle(.secondary) }
                    .frame(width: 48, height: 48)
                Text("New Playlist").font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            .padding(8)
            .contentShape(.rect)
            .background { if hovering { RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.07)) } }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("New Playlist (⌘N)")
    }
}

/// Clicking opens the playlist. Hovering shows a play button that starts it without opening it.
private struct PlaylistRow: View {
    let model: AppModel
    let playlist: Playlist
    let subtitle: String
    @State private var hovering = false

    var body: some View {
        Button { Task { await model.open(playlist) } } label: {
            HStack(spacing: 12) {
                Group {
                    if playlist.isLikedMusic { LikedTile(cornerRadius: 8) } else { RemoteImage(url: playlist.thumb, cornerRadius: 8) }
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.isLikedMusic ? "Liked Songs" : playlist.title).font(.callout.weight(.medium)).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if hovering {
                    Color.clear.frame(width: 28, height: 28)
                } else {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if hovering {
                Button { model.play(playlist) } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help("Play \(playlist.isLikedMusic ? "Liked Songs" : playlist.title)")
                .accessibilityLabel("Play")
            }
        }
        .background { if hovering { RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.07)) } }
        .onHover { hovering = $0 }
    }
}

// MARK: - Search

private struct SearchResults: View {
    let model: AppModel
    @State private var results: [Track] = []
    @State private var searching = false
    @State private var error: String?

    var body: some View {
        let query = model.searchQuery.trimmingCharacters(in: .whitespaces)
        let playlists = model.library.filter {
            ($0.isLikedMusic ? "Liked Songs" : $0.title).localizedStandardContains(query)
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !playlists.isEmpty {
                    SectionLabel("In Your Library")
                    ForEach(playlists) { playlist in
                        PlaylistRow(model: model, playlist: playlist,
                                    subtitle: playlist.isLikedMusic ? "Your liked songs" : playlist.subtitle)
                    }
                }
                SectionLabel("Songs")
                if let error {
                    Text(error).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 8)
                } else if results.isEmpty {
                    Group {
                        if searching { ProgressView().controlSize(.small) } else {
                            Text("No songs match \u{201C}\(query)\u{201D}.").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    ForEach(results) { track in
                        SongRow(model: model, track: track) { model.play(track) }
                    }
                    .opacity(searching ? 0.6 : 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.never)
        .fadingEdges()
        .task(id: query) { await run(query) }
    }

    private func run(_ text: String) async {
        guard !text.isEmpty else { results = []; error = nil; return }
        try? await Task.sleep(for: .milliseconds(300))
        if Task.isCancelled { return }
        searching = true
        defer { searching = false }
        do {
            let found = try await model.player.search(text)
            guard !Task.isCancelled else { return }
            results = found
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

/// A song with hover actions and the shared right-click menu.
private struct SongRow: View {
    let model: AppModel
    let track: Track
    var playlist: Playlist?
    var removable = false
    let play: () -> Void

    var body: some View {
        TrackRow(title: track.title, subtitle: track.subtitle, thumb: track.thumb,
                 isCurrent: track.videoId == model.player.state.videoId, action: play) {
            TrackActions(model: model, track: track, playlist: playlist, removable: removable, play: play)
        }
        .contextMenu {
            TrackMenuItems(model: model, track: track, playlist: playlist, removable: removable, play: play)
        }
    }
}

// MARK: - A playlist

private struct PlaylistView: View {
    let model: AppModel
    let playlist: Playlist
    @State private var confirmingDelete = false

    var body: some View {
        let detail = model.detail
        let header = detail?.playlist ?? playlist
        let removable = header.isLikedMusic || detail?.editable == true
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if header.isLikedMusic { LikedTile(cornerRadius: 12) } else { RemoteImage(url: header.thumb, cornerRadius: 12) }
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(header.isLikedMusic ? "Liked Songs" : header.title).font(.headline).lineLimit(2)
                    if let detail {
                        Text(summary(detail)).font(.caption).foregroundStyle(.secondary)
                    }
                    if confirmingDelete {
                        HStack(spacing: 8) {
                            Text("Delete this playlist?").font(.caption.weight(.semibold))
                            Button("Cancel") { confirmingDelete = false }
                            Button("Delete", role: .destructive) {
                                confirmingDelete = false
                                Task { await model.delete(header) }
                            }
                        }
                        .controlSize(.small)
                    } else {
                        HStack(spacing: 6) {
                            Button {
                                model.play(header)
                            } label: {
                                Label("Play", systemImage: "play.fill").font(.callout.weight(.semibold)).padding(.horizontal, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(detail?.tracks.isEmpty ?? true)
                            if let detail, detail.editable, !header.isLikedMusic {
                                GlyphMenu(symbol: "ellipsis", label: "Playlist Options", size: 28, font: .callout) {
                                    Button("Edit Details…") { model.startEditing(detail) }
                                    Divider()
                                    Button("Delete Playlist…") { confirmingDelete = true }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)

            if let detail {
                let tracks = detail.tracks.filter { track in
                    !(model.pendingRemoval?.playlist.id == header.id && model.pendingRemoval?.track.videoId == track.videoId)
                }
                if tracks.isEmpty {
                    Text(header.isLikedMusic ? "Songs you like show up here." : "No songs yet. Use the save button on any song to add it here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(tracks) { track in
                                SongRow(model: model, track: track, playlist: header, removable: removable) {
                                    model.play(header, from: track)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .scrollIndicators(.never)
                    .fadingEdges()
                }
            } else if let error = model.detailError {
                Text(error).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 18)
                Spacer()
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: playlist) { confirmingDelete = false }
    }

    private func summary(_ detail: PlaylistDetail) -> String {
        let count = detail.tracks.count == 1 ? "1 song" : "\(detail.tracks.count) songs"
        guard let privacy = detail.privacy, !detail.playlist.isLikedMusic else { return count }
        return "\(count) · \(privacy.title)"
    }
}

// MARK: - New Playlist and Edit Details

private struct PlaylistFormView: View {
    @Bindable var model: AppModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        if let form = model.form {
            let name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
            VStack(alignment: .leading, spacing: 14) {
                Text(isCreating(form) ? "New Playlist" : "Edit Details").font(.headline)
                TextField("Playlist name", text: Binding(get: { model.form?.name ?? "" }, set: { model.form?.name = $0 }))
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.primary.opacity(0.08), in: .rect(cornerRadius: 10))
                    .onSubmit { Task { await model.submitForm() } }
                Picker("Privacy", selection: Binding(get: { model.form?.privacy ?? .private }, set: { model.form?.privacy = $0 })) {
                    ForEach(PlaylistPrivacy.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if case .create(let seed?) = form.mode {
                    Toggle(isOn: Binding(get: { model.form?.includeSeed ?? false }, set: { model.form?.includeSeed = $0 })) {
                        HStack(spacing: 10) {
                            RemoteImage(url: seed.thumb, cornerRadius: 6).frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Start with \(seed.title)").font(.callout).lineLimit(1)
                                Text(seed.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(8)
                    .background(.primary.opacity(0.06), in: .rect(cornerRadius: 12))
                }
                if let error = form.error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Spacer()
                    if form.saving { ProgressView().controlSize(.small) }
                    Button("Cancel") { model.form = nil }
                    Button(isCreating(form) ? "Create" : "Save") { Task { await model.submitForm() } }
                        .disabled(name.isEmpty || form.saving)
                }
                .buttonBorderShape(.capsule)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .onAppear { nameFocused = true }
        }
    }

    private func isCreating(_ form: PlaylistForm) -> Bool {
        if case .create = form.mode { return true }
        return false
    }
}

/// Encore's own tile for liked songs, instead of YouTube Music's branded artwork.
private struct LikedTile: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.primary.opacity(0.2))
                .strokeBorder(.primary.opacity(0.15), lineWidth: 0.5)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: proxy.size.width * 0.4, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.9))
                }
        }
        .accessibilityHidden(true)
    }
}

/// Signed out: library and playlists need a Google account; search and playback don't.
struct ConnectView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Sign in to see your library").font(.headline)
            Text("Your liked songs and playlists come from your Google account. Search and playback work without signing in.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In with Google", action: model.signIn)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .frame(maxHeight: .infinity)
    }
}
