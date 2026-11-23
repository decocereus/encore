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
                case .playlists:
                    PlaylistPicker(model: model)
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
                    PaneToggle(model: model, pane: .playlists, symbol: "text.badge.plus",
                               label: "Add to Playlist", hideLabel: "Hide Playlists")
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

/// The account's playlists, checked where the current song already is. Clicking a row adds or removes it.
private struct PlaylistPicker: View {
    let model: AppModel

    var body: some View {
        let state = model.player.state
        let videoId = state.videoId
        VStack(alignment: .leading, spacing: 4) {
            Text("Add to Playlist").font(.subheadline.weight(.semibold)).padding(.leading, 18)
            if !state.signedIn {
                message("Sign in to add songs to your playlists.")
            } else if model.choicesVideoID == videoId, !model.choices.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.choices) { choice in
                            ChoiceRow(choice: choice) {
                                Task { await model.toggle(choice, videoId: videoId) }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.never)
                .fadingEdges()
            } else if let error = model.choicesError {
                message(error)
            } else if model.choicesVideoID == videoId {
                // Loaded, but there's nothing this account can edit.
                message("You don't have any playlists of your own yet.")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error = model.choicesError, !model.choices.isEmpty {
                Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(2).padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 6)
        .task(id: "\(videoId) \(state.signedIn)") {
            guard state.signedIn else { return }
            await model.loadChoices(for: videoId)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ChoiceRow: View {
    let choice: PlaylistChoice
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RemoteImage(url: choice.thumb, cornerRadius: 6)
                    .frame(width: 40, height: 40)
                Text(choice.title).font(.callout).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: choice.contains ? "checkmark.circle.fill" : "plus.circle")
                    .font(.body)
                    .foregroundStyle(choice.contains ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .opacity(choice.contains || hovering ? 1 : 0.5)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .background { if hovering { RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.07)) } }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(choice.title)
        .accessibilityValue(choice.contains ? "Contains this song" : "Doesn't contain this song")
        .accessibilityHint(choice.contains ? "Removes the song" : "Adds the song")
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
