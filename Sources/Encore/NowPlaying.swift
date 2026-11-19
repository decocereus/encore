import AppKit
import MediaPlayer

/// Publishes the current track to Control Center and routes media keys / AirPods taps to the player.
@MainActor
final class NowPlaying {
    private let center = MPNowPlayingInfoCenter.default()
    private var artwork: (url: URL, item: MPMediaItemArtwork)?
    private var artworkTask: Task<Void, Never>?
    private var lastState = TrackState()

    init(player: PlayerController) {
        let commands = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
            command.isEnabled = true
            command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
        }
        on(commands.togglePlayPauseCommand) { player.togglePlayPause() }
        on(commands.playCommand) { player.play() }
        on(commands.pauseCommand) { player.pause() }
        on(commands.nextTrackCommand) { player.next() }
        on(commands.previousTrackCommand) { player.previous() }

        commands.changePlaybackPositionCommand.isEnabled = true
        commands.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = event.positionTime
            Task { @MainActor in player.seek(to: time) }
            return .success
        }
    }

    func update(_ state: TrackState) {
        lastState = state
        guard state.hasTrack else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: state.title,
            MPMediaItemPropertyArtist: state.artist,
            MPMediaItemPropertyAlbumTitle: state.album,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.position,
            MPNowPlayingInfoPropertyPlaybackRate: state.playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork, artwork.url == state.artURL {
            info[MPMediaItemPropertyArtwork] = artwork.item
        } else if let url = state.artURL {
            loadArtwork(url)
        }
        center.nowPlayingInfo = info
        center.playbackState = state.playing ? .playing : .paused
    }

    private func loadArtwork(_ url: URL) {
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data), !Task.isCancelled else { return }
            let item = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            guard let self else { return }
            self.artwork = (url, item)
            if self.lastState.artURL == url { self.update(self.lastState) }
        }
    }
}
