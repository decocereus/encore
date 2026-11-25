import SwiftUI

/// Likes or unlikes the playing song. Hidden when signed out or nothing is playing.
struct LikeButton: View {
    let model: AppModel
    var size: CGFloat = 28
    var font: Font = .callout

    var body: some View {
        if let track = model.currentTrack, model.player.state.signedIn {
            let liked = model.likeStatus(of: track) == .like
            GlyphButton(symbol: liked ? "heart.fill" : "heart", label: liked ? "Remove from Liked Songs" : "Like",
                        size: size, font: font) {
                Task { await model.rate(track, .like) }
            }
            .contentTransition(.symbolEffect(.replace))
        }
    }
}

/// The playing song's playlists in a native menu with checkmarks. Its glyph fills in, with a count,
/// when the song is already in one or more playlists.
struct SaveMenu: View {
    let model: AppModel
    var size: CGFloat = 28
    var font: Font = .callout
    @State private var hovering = false

    var body: some View {
        if let track = model.currentTrack {
            let saved = model.playlists(containing: track.videoId)
            Menu {
                SaveMenuItems(model: model, track: track)
                if model.player.state.signedIn {
                    Divider()
                    RatingItems(model: model, track: track)
                }
            } label: {
                Image(systemName: Self.symbol(count: saved.count))
                    .font(font)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: size, height: size)
                    .background { if hovering { Circle().fill(.primary.opacity(0.1)) } }
                    .contentShape(.circle)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .onHover { hovering = $0 }
            .help(saved.isEmpty ? "Save to Playlist" : "In " + saved.map(\.title).formatted(.list(type: .and)))
            .accessibilityLabel("Save to Playlist")
            .accessibilityValue(saved.isEmpty ? "Not in any playlist" : "In \(saved.count) playlists")
        }
    }

    /// A plus when the song is in no playlist, otherwise the number of playlists it's in (SF Symbols go up to 50).
    static func symbol(count: Int) -> String {
        switch count {
        case 0: "plus.circle"
        case 1...50: "\(count).circle.fill"
        default: "checkmark.circle.fill"
        }
    }
}

/// Save to Playlist items for any song: the account's playlists, checked where the song already is.
/// Choosing one adds the song or takes it out.
struct SaveMenuItems: View {
    let model: AppModel
    let track: Track

    var body: some View {
        if !model.player.state.signedIn {
            Button("Sign In to Save…", action: model.signIn)
        } else {
            if !model.playlistsLoaded {
                if model.playlistsError != nil {
                    Button("Try Loading Playlists Again") { Task { await model.loadPlaylists(force: true) } }
                } else {
                    Text("Loading playlists…")
                }
            }
            ForEach(model.editablePlaylists) { choice in
                let saved = model.contains(track.videoId, in: choice)
                Toggle(choice.title, isOn: Binding(
                    get: { saved },
                    set: { _ in Task { await model.setSaved(track, in: choice, !saved) } }))
            }
            Divider()
            Button("New Playlist…") { model.startNewPlaylist(with: track) }
        }
    }
}

/// Like and Dislike as checkable menu items.
struct RatingItems: View {
    let model: AppModel
    let track: Track
    var playlist: Playlist?

    var body: some View {
        let status = model.likeStatus(of: track, in: playlist)
        Toggle("Like", isOn: Binding(get: { status == .like },
                                     set: { _ in Task { await model.rate(track, .like, in: playlist) } }))
        Toggle("Dislike", isOn: Binding(get: { status == .dislike },
                                        set: { _ in Task { await model.rate(track, .dislike, in: playlist) } }))
    }
}

/// Everything you can do with a song in a list: the ⋯ button and the right-click menu share it.
struct TrackMenuItems: View {
    let model: AppModel
    let track: Track
    var playlist: Playlist?
    var removable = false
    let play: () -> Void

    var body: some View {
        Button("Play", action: play)
        if model.player.state.signedIn {
            Divider()
            RatingItems(model: model, track: track, playlist: playlist)
        }
        Divider()
        Menu("Save to Playlist") { SaveMenuItems(model: model, track: track) }
        if removable, let playlist {
            Button(playlist.isLikedMusic ? "Remove from Liked Songs" : "Remove from This Playlist") {
                model.remove(track, from: playlist)
            }
        }
    }
}

/// Hover buttons on a song row: like, then either save or remove, then the full menu.
struct TrackActions: View {
    let model: AppModel
    let track: Track
    var playlist: Playlist?
    var removable = false
    let play: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if model.player.state.signedIn {
                let liked = model.likeStatus(of: track, in: playlist) == .like
                GlyphButton(symbol: liked ? "heart.fill" : "heart", label: liked ? "Remove from Liked Songs" : "Like",
                            size: 26, font: .caption) {
                    Task { await model.rate(track, .like, in: playlist) }
                }
                if removable, let playlist {
                    GlyphButton(symbol: "minus.circle", label: playlist.isLikedMusic ? "Remove from Liked Songs" : "Remove from Playlist",
                                size: 26, font: .caption) {
                        model.remove(track, from: playlist)
                    }
                } else {
                    GlyphMenu(symbol: "plus.circle", label: "Save to Playlist") {
                        SaveMenuItems(model: model, track: track)
                    }
                }
            }
            GlyphMenu(symbol: "ellipsis", label: "More") {
                TrackMenuItems(model: model, track: track, playlist: playlist, removable: removable, play: play)
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// A Glyph Button that opens a native menu.
struct GlyphMenu<Content: View>: View {
    let symbol: String
    let label: String
    var size: CGFloat = 26
    var font: Font = .caption
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Menu(content: content) {
            Image(systemName: symbol)
                .font(font)
                .frame(width: size, height: size)
                .background { if hovering { Circle().fill(.primary.opacity(0.1)) } }
                .contentShape(.circle)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A short message above the tab bar, with Undo when the action can be taken back.
struct ToastView: View {
    let model: AppModel

    var body: some View {
        if let toast = model.toast {
            HStack(spacing: 8) {
                Text(toast.text).lineLimit(1)
                if let undo = toast.undo {
                    Button("Undo") {
                        undo()
                        model.toast = nil
                    }
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(.primary.opacity(0.14), in: .capsule)
            .padding(.horizontal, 24)
            .id(toast.id)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
