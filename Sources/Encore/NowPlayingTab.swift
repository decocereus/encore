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
                if model.showQueue {
                    UpNextList(model: model)
                        .frame(height: 248)
                        .transition(.opacity)
                } else {
                    RemoteImage(url: state.artURL, cornerRadius: 18)
                        .matchedGeometryEffect(id: "art", in: namespace)
                        .frame(width: 232, height: 232)
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                        .padding(.vertical, 8)
                        .transition(.opacity)
                }

                VStack(spacing: 2) {
                    Text(state.title).font(.title3.weight(.semibold)).lineLimit(1)
                    Text(state.album.isEmpty ? state.artist : "\(state.artist) · \(state.album)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                Scrubber(player: player).padding(.horizontal, 24)

                HStack(spacing: 28) {
                    GlyphButton(symbol: "backward.fill", label: "Previous", size: 44, font: .title3, action: player.previous)
                    PlayPauseButton(player: player, size: 56)
                        .keyboardShortcut(.space, modifiers: [])
                    GlyphButton(symbol: "forward.fill", label: "Next", size: 44, font: .title3, action: player.next)
                }

                HStack(spacing: 8) {
                    VolumeSlider(player: player)
                    GlyphButton(symbol: "list.bullet", label: model.showQueue ? "Hide Up Next" : "Up Next",
                                size: 30, font: .callout.weight(.semibold)) {
                        model.showQueue.toggle()
                    }
                    .foregroundStyle(model.showQueue ? .primary : .secondary)
                    .background { if model.showQueue { Circle().fill(.primary.opacity(0.2)) } }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: .infinity)
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
            HStack(spacing: 8) {
                Button("Library") { model.tab = .library }
                Button("Search") { model.tab = .search }
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity)
    }
}
