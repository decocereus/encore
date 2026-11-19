import SwiftUI

struct RemoteImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 8

    var body: some View {
        // Color.clear takes the frame the caller sets, so wide video thumbnails are cropped to it.
        Color.clear
            .overlay {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(.quaternary)
                            .overlay { Image(systemName: "music.note").foregroundStyle(.tertiary) }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}

/// The current artwork, blurred, laid under the panel's glass so the whole player takes on the cover's colour.
struct ArtworkTint: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
                    .blur(radius: 40)
                    .opacity(0.5)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: url)
        .allowsHitTesting(false)
    }
}

struct TrackRow: View {
    let title: String
    let subtitle: String
    let thumb: URL?
    var isCurrent = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RemoteImage(url: thumb, cornerRadius: 6)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(isCurrent ? .semibold : .regular)).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "waveform").font(.caption).foregroundStyle(.secondary)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                } else if hovering {
                    Image(systemName: "play.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .background { if hovering { RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.07)) } }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

struct PlayPauseButton: View {
    let player: PlayerController
    var size: CGFloat

    var body: some View {
        Button(action: player.togglePlayPause) {
            Image(systemName: player.state.playing ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!player.state.hasTrack)
        .opacity(player.state.hasTrack ? 1 : 0.45)
        .accessibilityLabel(player.state.playing ? "Pause" : "Play")
    }
}

/// The player's own volume (ducking never moves it), between quiet and loud speaker glyphs.
struct VolumeSlider: View {
    let player: PlayerController

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
            Slider(value: Binding(get: { player.state.volume }, set: { player.setVolume($0) }), in: 0...100)
                .controlSize(.mini)
                .tint(.primary)
                .accessibilityLabel("Volume")
            Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Icon-only control drawn on the glass: no chrome of its own, a soft fill on hover.
struct GlyphButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 32
    var font: Font = .body
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(font)
                .frame(width: size, height: size)
                .background { if hovering { Circle().fill(.primary.opacity(0.1)) } }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct Scrubber: View {
    let player: PlayerController
    @State private var dragging: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let state = player.state
            let position = dragging ?? state.position(at: context.date)
            VStack(spacing: 2) {
                Slider(value: Binding(get: { position }, set: { dragging = $0 }),
                       in: 0...max(state.duration, 1)) { editing in
                    if !editing, let target = dragging {
                        player.seek(to: target)
                        dragging = nil
                    }
                }
                .controlSize(.small)
                .tint(.primary)
                .accessibilityLabel("Playback position")
                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text("-" + formatTime(max(0, state.duration - position)))
                }
                .contentTransition(.numericText())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// A hairline of progress along the bottom of the compact pill.
struct ProgressLine: View {
    let player: PlayerController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = player.state
            let fraction = state.duration > 0 ? state.position(at: context.date) / state.duration : 0
            GeometryReader { proxy in
                Capsule().fill(.primary.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.55)).frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 2)
        }
        .accessibilityHidden(true)
    }
}

/// Shown while a dictation app has the mic and the music is lowered.
struct DuckBadge: View {
    let appName: String

    var body: some View {
        Label("Lowered for \(appName)", systemImage: "waveform")
            .symbolEffect(.variableColor.iterative, options: .repeating)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(.primary.opacity(0.1), in: .capsule)
    }
}

extension View {
    /// Fades list content out at its edges instead of slicing rows at the frame.
    func fadingEdges(top: CGFloat = 10, bottom: CGFloat = 28) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: top)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: bottom)
            }
        }
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}
