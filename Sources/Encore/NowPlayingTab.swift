import SwiftUI

struct NowPlayingTab: View {
    let model: AppModel
    let namespace: Namespace.ID

    var body: some View {
        let player = model.player
        let state = player.state
        if !state.hasTrack {
            EmptyNowPlaying(model: model)
        } else {
            VStack(spacing: 14) {
                switch model.pane {
                case .upNext:
                    UpNextList(model: model)
                        .frame(height: 248)
                        .transition(.opacity)
                case .artwork:
                    RemoteImage(url: state.artURL, cornerRadius: 18)
                        .matchedGeometryEffect(id: "art", in: namespace)
                        .frame(width: 232, height: 232)
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                        .padding(.vertical, 8)
                        .transition(.opacity)
                }

                HStack(spacing: 6) {
                    LikeButton(model: model, size: 30, font: .body)
                        .keyboardShortcut("l", modifiers: [])
                        .frame(width: 30)
                    VStack(spacing: 2) {
                        Text(state.title).font(.title3.weight(.semibold)).lineLimit(1)
                        Text(state.album.isEmpty ? state.artist : "\(state.artist) · \(state.album)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    SaveMenu(model: model, size: 30, font: .body)
                        .frame(width: 30)
                }
                .padding(.horizontal, 18)
                .background { DislikeShortcut(model: model) }

                Scrubber(player: player).padding(.horizontal, 24)

                HStack(spacing: 28) {
                    GlyphButton(symbol: "backward.fill", label: "Previous", size: 44, font: .title3, action: player.previous)
                    PlayPauseButton(player: player, size: 56)
                        .keyboardShortcut(.space, modifiers: [])
                    GlyphButton(symbol: "forward.fill", label: "Next", size: 44, font: .title3, action: player.next)
                }

                HStack(spacing: 8) {
                    VolumeSlider(player: player)
                    PaneToggle(model: model, pane: .upNext, symbol: "list.bullet",
                               label: "Up Next", hideLabel: "Hide Up Next")
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// Swaps the artwork for a list, and back.
private struct PaneToggle: View {
    let model: AppModel
    let pane: NowPlayingPane
    let symbol: String
    let label: String
    let hideLabel: String

    var body: some View {
        let isOn = model.pane == pane
        GlyphButton(symbol: symbol, label: isOn ? hideLabel : label, size: 30, font: .callout.weight(.semibold)) {
            model.pane = isOn ? .artwork : pane
        }
        .foregroundStyle(isOn ? .primary : .secondary)
        .background { if isOn { Circle().fill(.primary.opacity(0.2)) } }
    }
}

/// D dislikes the playing song, which also skips it.
private struct DislikeShortcut: View {
    let model: AppModel

    var body: some View {
        if let track = model.currentTrack, model.player.state.signedIn {
            Button("Dislike") { Task { await model.rate(track, .dislike) } }
                .keyboardShortcut("d", modifiers: [])
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

private struct UpNextList: View {
    let model: AppModel

    var body: some View {
        let state = model.player.state
        let queue = state.queue
        // The "selected" flag lags after skips, so find the current song by title.
        let current = queue.firstIndex { $0.title == state.title } ?? queue.firstIndex(where: \.selected) ?? -1
        let upcoming = Array(queue.dropFirst(current + 1))
        VStack(alignment: .leading, spacing: 4) {
            Text("Up Next").font(.subheadline.weight(.semibold)).padding(.leading, 18)
            if upcoming.isEmpty {
                Text("Nothing queued after this song.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(upcoming) { item in
                            TrackRow(title: item.title, subtitle: item.artist, thumb: item.thumb) {
                                model.player.playQueueItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.never)
                .fadingEdges()
            }
        }
        .padding(.bottom, 6)
    }
}

private struct EmptyNowPlaying: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 96, height: 96)
                .background(.primary.opacity(0.06), in: .rect(cornerRadius: 22))
            Text(model.player.pageLoaded ? "Nothing playing" : "Starting YouTube Music…")
                .font(.headline)
            Text("Pick something from your library or search for a song.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Library") { model.tab = .library }
                .controlSize(.large)
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity)
    }
}
