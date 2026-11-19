import AppKit
import SwiftUI
import WebKit

/// Borderless, transparent panel that holds the glass player under the menu bar.
private final class PlayerPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let profiles = ProfileStore()
    private let player = PlayerController()
    private let ducking = DuckingSettings()
    private var model: AppModel!
    private var nowPlaying: NowPlaying!
    private var statusItem: NSStatusItem!
    private var panel: PlayerPanel!
    private var settingsWindow: NSWindow?
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?

    private static let panelSize = NSSize(width: PanelMetrics.width + PanelMetrics.margin * 2,
                                          height: PanelMetrics.drawerHeight + PanelMetrics.margin * 2)

    /// Hosts the YouTube Music page. Never shown in normal use; playback runs while it stays hidden.
    private let webWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel(player: player, profiles: profiles, ducking: ducking,
                         ducker: Ducker(player: player, settings: ducking))
        model.openSettings = { [weak self] in self?.showSettings() }
        model.hidePanel = { [weak self] in self?.hidePanel() }
        model.showPanel = { [weak self] in self?.showPanel() }
        nowPlaying = NowPlaying(player: player)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.icon(playing: false)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hosting = NSHostingView(rootView: EncoreView(model: model))
        hosting.frame = NSRect(origin: .zero, size: Self.panelSize)
        panel = PlayerPanel(contentView: hosting, size: Self.panelSize)
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.autoHide() }
        }

        webWindow.title = "YouTube Music"
        webWindow.isReleasedWhenClosed = false
        webWindow.center()

        player.onWebViewReplaced = { [weak self] view in self?.embed(view) }
        player.onState = { [weak self] state in self?.render(state) }
        player.load(profile: profiles.current)
    }

    // MARK: Status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            hidePanel()
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if event?.modifierFlags.contains(.option) == true {
            player.togglePlayPause()
        } else if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        positionPanel()
        panel.orderFrontRegardless()
        panel.makeKey()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.autoHide() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Escape collapses the drawer (handled by its button), then hides the pill.
            if event.keyCode == 53, let self, !self.model.expanded {
                self.hidePanel()
                return nil
            }
            return event
        }
    }

    /// Clicking away hides the panel, except during sign-in, when the user may switch to a password manager or their phone.
    private func autoHide() {
        guard !model.signingIn else { return }
        hidePanel()
    }

    private func hidePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        model.expanded = false
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
    }

    /// Hangs the panel just under the status item, or at the right edge when the menu bar has hidden the item.
    private func positionPanel() {
        let size = Self.panelSize
        let screen = statusItem.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var x = visible.maxX - size.width - 4
        if let button = statusItem.button, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            if screen.frame.contains(NSPoint(x: rect.midX, y: rect.midY)) {
                x = rect.midX - size.width / 2
            }
        }
        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        let top = visible.maxY + PanelMetrics.margin - 6
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
    }

    private func embed(_ view: WKWebView) {
        let content = NSView()
        view.frame = content.bounds
        view.autoresizingMask = [.width, .height]
        content.addSubview(view)
        webWindow.contentView = content
    }

    private func render(_ state: TrackState) {
        nowPlaying.update(state)
        statusItem.button?.image = Self.icon(playing: state.playing)
        statusItem.button?.toolTip = state.hasTrack ? "\(state.title) · \(state.artist)" : "Encore"
    }

    private static func icon(playing: Bool) -> NSImage? {
        let image = NSImage(systemSymbolName: playing ? "music.note" : "music.note.list", accessibilityDescription: "Encore")
        image?.isTemplate = true
        return image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let state = player.state
        if state.hasTrack {
            let title = NSMenuItem(title: "\(state.title) · \(state.artist)", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
            menu.addItem(.separator())
        }
        menu.addItem(item(state.playing ? "Pause" : "Play", #selector(playPause)))
        menu.addItem(item("Next", #selector(nextTrack)))
        menu.addItem(item("Previous", #selector(previousTrack)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettingsFromMenu), key: ","))
        menu.addItem(item("Show Web Player", #selector(showWebPlayer)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Encore", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func playPause() { player.togglePlayPause() }
    @objc private func nextTrack() { player.next() }
    @objc private func previousTrack() { player.previous() }
    @objc private func openSettingsFromMenu() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showWebPlayer() {
        NSApp.activate()
        webWindow.makeKeyAndOrderFront(nil)
    }

    private func showSettings() {
        hidePanel()
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Encore Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
