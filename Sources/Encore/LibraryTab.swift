import SwiftUI

struct LibraryTab: View {
    let model: AppModel

    var body: some View {
        let player = model.player
        Group {
            if !player.pageLoaded {
                ProgressView().frame(maxHeight: .infinity)
            } else if !player.state.signedIn {
                ConnectView(model: model)
            } else if let playlist = model.openPlaylist {
                PlaylistView(model: model, playlist: playlist)
            } else {
                PlaylistList(model: model)
            }
        }
        .task(id: "\(model.profiles.currentID)-\(player.state.signedIn)") {
            if player.state.signedIn { await model.loadLibrary() }
        }
    }
}

private struct PlaylistList: View {
    let model: AppModel

    var body: some View {
        if model.library.isEmpty {
            VStack(spacing: 10) {
                if model.libraryLoading {
                    ProgressView()
                } else if let error = model.libraryError {
                    Text("Couldn't load your library").font(.headline)
                    Text(error).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try Again") { Task { await model.loadLibrary(force: true) } }
                } else {
                    Text("No playlists yet").font(.headline)
                    Text("Songs you like and playlists you save on YouTube Music show up here.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let liked = model.library.filter(\.isLikedMusic)
                    let others = model.library.filter { !$0.isLikedMusic }
                    ForEach(liked) { playlist in
                        PlaylistRow(playlist: playlist, subtitle: "Your liked songs") { Task { await model.open(playlist) } }
                    }
                    if !others.isEmpty {
                        Text("Playlists")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                        ForEach(others) { playlist in
                            PlaylistRow(playlist: playlist, subtitle: playlist.subtitle) { Task { await model.open(playlist) } }
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

private struct PlaylistRow: View {
    let playlist: Playlist
    let subtitle: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
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
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(8)
            .contentShape(.rect)
            .background { if hovering { RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.07)) } }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct PlaylistView: View {
    let model: AppModel
    let playlist: Playlist

    var body: some View {
        let detail = model.detail
        let header = detail?.playlist ?? playlist
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if header.isLikedMusic { LikedTile(cornerRadius: 12) } else { RemoteImage(url: header.thumb, cornerRadius: 12) }
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(header.isLikedMusic ? "Liked Songs" : header.title).font(.headline).lineLimit(2)
                    if let detail {
                        Text("\(detail.tracks.count) songs").font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        model.play(header)
                    } label: {
                        Label("Play", systemImage: "play.fill").font(.callout.weight(.semibold)).padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(detail?.tracks.isEmpty ?? true)
                }
            }
            .padding(.horizontal, 18)

            if let detail {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(detail.tracks) { track in
                            TrackRow(title: track.title, subtitle: track.subtitle, thumb: track.thumb,
                                     isCurrent: track.title == model.player.state.title) {
                                model.play(header, from: track)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.never)
                .fadingEdges()
            } else if let error = model.detailError {
                Text(error).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 18)
                Spacer()
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Encore's own tile for liked songs, instead of YouTube Music's branded artwork.
private struct LikedTile: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.primary.opacity(0.12))
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .accessibilityHidden(true)
    }
}

/// Signed out: connect the account the user is already signed into in a browser.
struct ConnectView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Connect YouTube Music").font(.headline)
            Text(model.browserProfiles.isEmpty
                 ? "Sign in at music.youtube.com in Helium, Chrome, Arc, Brave or Edge, then check again."
                 : "Encore uses the account you're already signed into in your browser.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if model.browserProfiles.isEmpty {
                Button("Check Again", action: model.refreshBrowserProfiles)
            } else {
                VStack(spacing: 6) {
                    ForEach(model.browserProfiles) { source in
                        SourceRow(source: source, connecting: model.connecting == source.id) {
                            Task { await model.connect(source) }
                        }
                        .disabled(model.connecting != nil)
                    }
                }
                .padding(.top, 4)
                Text("macOS will ask to let Encore read that browser's cookie key. Choose Always Allow so Encore can reconnect by itself when Google refreshes the session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let error = model.connectError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
        .onAppear(perform: model.refreshBrowserProfiles)
    }
}

private struct SourceRow: View {
    let source: BrowserProfile
    let connecting: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let icon = source.browser.icon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "globe").font(.title3).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 26, height: 26)
                Text(source.browser.name).font(.callout.weight(.medium))
                Text(source.name).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if connecting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .contentShape(.rect)
            .background(.primary.opacity(hovering ? 0.1 : 0.06), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
