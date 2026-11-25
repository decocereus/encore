import SwiftUI

enum PanelMetrics {
    static let width: CGFloat = 360
    static let pillHeight: CGFloat = 128
    static let drawerHeight: CGFloat = 620
    static let radius: CGFloat = 28
    /// Room around the shape for the glass edge and shadow.
    static let margin: CGFloat = 12
}

/// The whole player: a glass pill that grows downward into the drawer.
struct EncoreView: View {
    let model: AppModel
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded {
                Drawer(model: model, namespace: namespace)
                    .transition(.opacity)
            } else {
                Pill(model: model, namespace: namespace)
                    .transition(.opacity)
            }
        }
        .frame(width: PanelMetrics.width,
               height: model.expanded ? PanelMetrics.drawerHeight : PanelMetrics.pillHeight,
               alignment: .top)
        .clipShape(.rect(cornerRadius: PanelMetrics.radius))
        .glassEffect(.regular, in: .rect(cornerRadius: PanelMetrics.radius))
        .padding(PanelMetrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86),
                   value: model.expanded)
        .animation(.easeInOut(duration: 0.25), value: model.tab)
        .animation(.easeInOut(duration: 0.25), value: model.pane)
        .animation(.easeInOut(duration: 0.2), value: model.toast?.id)
        // The heart shows the playing song's rating, fetched once per song.
        .task(id: "\(model.player.state.videoId) \(model.player.state.signedIn)") {
            let state = model.player.state
            guard state.signedIn, !state.videoId.isEmpty else { return }
            await model.loadLikeStatus(for: state.videoId)
        }
        // Which playlists hold which songs, for the save glyph and every Save to Playlist menu.
        .task(id: "\(model.profiles.currentID) \(model.player.state.signedIn)") {
            guard model.player.state.signedIn else { return }
            await model.loadPlaylists()
        }
    }
}

// MARK: - Compact

private struct Pill: View {
    let model: AppModel
    let namespace: Namespace.ID

    var body: some View {
        let player = model.player
        let state = player.state
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                RemoteImage(url: state.artURL, cornerRadius: 20)
                    .matchedGeometryEffect(id: "art", in: namespace)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.hasTrack ? state.title : "Nothing playing")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Group {
                        if let app = model.duckedFor {
                            Label("Lowered for \(app)", systemImage: "waveform")
                                .symbolEffect(.variableColor.iterative, options: .repeating)
                        } else {
                            Text(state.hasTrack ? state.artist : "Open to browse your library")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 0) {
                    LikeButton(model: model)
                    SaveMenu(model: model)
                }

                GlyphButton(symbol: "chevron.down", label: "Expand", size: 28, font: .callout.weight(.semibold)) {
                    model.expanded = true
                }
            }
            // Only the track row expands on click; the sliders below need their clicks.
            .contentShape(.rect)
            .onTapGesture { model.expanded = true }

            CompactScrubber(player: player)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                VolumeSlider(player: player)
                    .frame(width: 132)
                Spacer(minLength: 8)
                GlyphButton(symbol: "backward.fill", label: "Previous", size: 32, font: .callout, action: player.previous)
                PlayPauseButton(player: player, size: 36)
                GlyphButton(symbol: "forward.fill", label: "Next", size: 32, font: .callout, action: player.next)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(height: PanelMetrics.pillHeight, alignment: .top)
        .contextMenu { PlayerMenu(model: model) }
    }
}

// MARK: - Expanded

private struct Drawer: View {
    let model: AppModel
    let namespace: Namespace.ID

    var body: some View {
        if model.signingIn {
            SignInSheet(model: model)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            DrawerHeader(model: model)
            Group {
                switch model.tab {
                case .nowPlaying: NowPlayingTab(model: model, namespace: namespace)
                case .library: LibraryTab(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .bottom) { ToastView(model: model).padding(.bottom, 4) }
            TabBar(model: model)
                .padding(.bottom, 12)
                .padding(.top, 6)
        }
        .background {
            Button("New Playlist") { model.startNewPlaylist(with: nil) }
                .keyboardShortcut("n", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

private struct DrawerHeader: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if model.tab == .library, model.form != nil || model.openPlaylist != nil {
                GlyphButton(symbol: "chevron.left", label: "Back", size: 32, font: .callout.weight(.semibold)) {
                    if model.form != nil { model.form = nil } else { model.openPlaylist = nil }
                }
                .keyboardShortcut("[", modifiers: .command)
            } else {
                AccountMenu(model: model)
            }
            if let app = model.duckedFor {
                Spacer(minLength: 0)
                DuckBadge(appName: app)
                Spacer(minLength: 0)
            } else if model.tab != .nowPlaying, model.player.state.hasTrack {
                MiniNowPlaying(model: model)
            } else {
                Spacer(minLength: 0)
            }
            GlyphButton(symbol: "chevron.up", label: "Collapse", size: 32, font: .callout.weight(.semibold)) {
                model.expanded = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }
}

/// Keeps what's playing visible on Library and Search; tapping it returns to Now Playing.
private struct MiniNowPlaying: View {
    let model: AppModel

    var body: some View {
        let state = model.player.state
        HStack(spacing: 8) {
            Button {
                model.tab = .nowPlaying
            } label: {
                HStack(spacing: 8) {
                    RemoteImage(url: state.artURL, cornerRadius: 15).frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.title).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(state.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Now playing: \(state.title), \(state.artist)")
            LikeButton(model: model, font: .caption)
            PlayPauseButton(player: model.player, size: 28)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AccountMenu: View {
    let model: AppModel

    var body: some View {
        Menu {
            Section("Accounts") {
                ForEach(model.profiles.profiles) { profile in
                    Toggle(profile.name, isOn: Binding(
                        get: { profile.id == model.profiles.currentID },
                        set: { if $0 { model.select(profile) } }))
                }
                Button("Add Account…", action: model.addAccount)
                if !model.player.state.signedIn {
                    Button("Sign In…", action: model.signIn)
                }
            }
            Divider()
            PlayerMenu(model: model)
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help(model.profiles.current.name)
        .accessibilityLabel("Account and settings")
    }
}

/// Shared by the pill's context menu and the account menu.
struct PlayerMenu: View {
    let model: AppModel

    var body: some View {
        Button("Previous", action: model.player.previous)
        Button("Next", action: model.player.next)
        Divider()
        Button("Settings…", action: model.openSettings)
        Button("Quit Encore") { NSApp.terminate(nil) }
    }
}

private struct TabBar: View {
    let model: AppModel
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DrawerTab.allCases) { tab in
                let selected = model.tab == tab
                Button {
                    model.tab = tab
                } label: {
                    Label(tab.title, systemImage: tab.symbol)
                        .font(.caption.weight(.medium))
                        .symbolVariant(selected ? .fill : .none)
                        .foregroundStyle(selected ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background {
                            if selected {
                                Capsule().fill(.primary.opacity(0.14))
                                    .matchedGeometryEffect(id: "tab", in: selection)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
