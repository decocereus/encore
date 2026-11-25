import AppKit
import Observation
import WebKit

struct QueueItem: Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var title: String
    var artist: String
    var thumb: URL?
    var selected: Bool
}

/// Thumbs up, thumbs down, or neither. Liking a song puts it in Liked Songs.
enum LikeStatus: String {
    case like = "LIKE"
    case dislike = "DISLIKE"
    case indifferent = "INDIFFERENT"
}

enum PlaylistPrivacy: String, CaseIterable, Identifiable {
    case `private` = "PRIVATE"
    case unlisted = "UNLISTED"
    case `public` = "PUBLIC"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private: "Private"
        case .unlisted: "Unlisted"
        case .public: "Public"
        }
    }
}

struct Track: Identifiable, Equatable, Hashable {
    var id: String { videoId }
    var videoId: String
    var title: String
    var subtitle: String
    var thumb: URL?
    /// What YouTube Music reported with the list, when it said.
    var likeStatus: LikeStatus?
}

/// A playlist, including Liked Music. `id` is the InnerTube browse ID ("VL…").
struct Playlist: Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var thumb: URL?

    var isLikedMusic: Bool { id == "VLLM" }
    /// The bare playlist ID that edit calls take.
    var playlistID: String { id.hasPrefix("VL") ? String(id.dropFirst(2)) : id }
}

/// A playlist the current account can edit. `id` is the bare playlist ID, without the "VL" browse prefix.
struct PlaylistChoice: Identifiable, Equatable {
    var id: String
    var title: String
    var thumb: URL?

    var browseID: String { "VL" + id }
}

struct PlaylistDetail: Equatable {
    var playlist: Playlist
    var tracks: [Track]
    /// The account owns it, so it can be renamed, deleted and have songs removed.
    var editable = false
    var privacy: PlaylistPrivacy?
}

struct TrackState: Equatable {
    var videoId = ""
    var title = ""
    var artist = ""
    var album = ""
    var artURL: URL?
    var playing = false
    var position: Double = 0
    /// When `position` was read, so the UI can advance it between reports.
    var positionDate = Date()
    var duration: Double = 0
    var volume: Double = 100
    var signedIn = false
    var queue: [QueueItem] = []

    var hasTrack: Bool { !title.isEmpty }

    func position(at date: Date) -> Double {
        guard playing else { return position }
        return min(duration, position + date.timeIntervalSince(positionDate))
    }
}

/// Owns the hidden WKWebView running music.youtube.com and drives it through the injected bridge.
@MainActor
@Observable
final class PlayerController: NSObject {
    @ObservationIgnored private(set) var webView: WKWebView?
    @ObservationIgnored var onState: ((TrackState) -> Void)?
    @ObservationIgnored var onWebViewReplaced: ((WKWebView) -> Void)?

    private(set) var state = TrackState()
    private(set) var pageLoaded = false

    private static let home = URL(string: "https://music.youtube.com")!
    // Google refuses sign-in from user agents it doesn't recognise, so present as Safari.
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    private static let allowedHosts = ["youtube.com", "google.com", "gstatic.com", "googleusercontent.com", "ytimg.com", "youtube-nocookie.com"]

    func load(profile: Profile) {
        if let old = webView {
            old.pauseAllMediaPlayback(completionHandler: nil)
            old.configuration.userContentController.removeScriptMessageHandler(forName: "ytm")
            old.stopLoading()
            old.removeFromSuperview()
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        config.mediaTypesRequiringUserActionForPlayback = []
        let scripts = config.userContentController
        scripts.addUserScript(WKUserScript(source: mediaHandlersScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        scripts.addUserScript(WKUserScript(source: bridgeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        scripts.add(WeakMessageHandler(self), name: "ytm")

        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 720), configuration: config)
        view.customUserAgent = Self.userAgent
        view.uiDelegate = self
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: Self.home))

        webView = view
        pageLoaded = false
        state = TrackState()
        onState?(state)
        onWebViewReplaced?(view)
    }

    /// The current account's cookie store, shared with the sign-in sheet.
    var dataStore: WKWebsiteDataStore? { webView?.configuration.websiteDataStore }

    func goHome() {
        pageLoaded = false
        webView?.load(URLRequest(url: Self.home))
    }

    func togglePlayPause() { run("toggle()") }
    func play() { run("play()") }
    func pause() { run("pause()") }
    func next() { run("next()") }
    func previous() { run("prev()") }

    func seek(to seconds: Double) {
        state.position = seconds
        state.positionDate = Date()
        run("seek(\(seconds))")
    }

    func setVolume(_ volume: Double) {
        state.volume = volume
        run("setVolume(\(Int(volume.rounded())))")
    }

    func playQueueItem(_ item: QueueItem) { run("playQueueItem(\(item.index))") }

    func play(_ result: Track) {
        callBridge("playVideo(videoId)", arguments: ["videoId": result.videoId])
    }

    func play(_ collection: Playlist, startingAt track: Track? = nil) {
        callBridge("playPlaylist(id, videoId)", arguments: ["id": collection.id, "videoId": track?.videoId ?? NSNull()])
    }

    /// Scales playback volume under the user's own volume; 1 means no ducking.
    func duck(_ factor: Double) { run("duck(\(factor))") }

    func search(_ query: String) async throws -> [Track] {
        let rows = try await ask("return await window.__ytmbar.search(query)", ["query": query]) as? [[String: Any]] ?? []
        return rows.compactMap(Self.track)
    }

    func library() async throws -> [Playlist] {
        let rows = try await ask("return await window.__ytmbar.library()") as? [[String: Any]] ?? []
        return rows.compactMap(Self.collection)
    }

    func playlist(_ collection: Playlist) async throws -> PlaylistDetail {
        let dict = try await ask("return await window.__ytmbar.playlist(id)", ["id": collection.id]) as? [String: Any] ?? [:]
        var header = Self.collection(dict) ?? collection
        if header.title.isEmpty { header.title = collection.title }
        if header.thumb == nil { header.thumb = collection.thumb }
        let tracks = (dict["tracks"] as? [[String: Any]] ?? []).compactMap(Self.track)
        return PlaylistDetail(playlist: header, tracks: tracks,
                              editable: dict["editable"] as? Bool ?? false,
                              privacy: (dict["privacy"] as? String).flatMap(PlaylistPrivacy.init(rawValue:)))
    }

    /// Likes, dislikes or clears the rating of a song.
    func rate(_ videoId: String, _ status: LikeStatus) async throws {
        _ = try await ask("return await window.__ytmbar.rate(videoId, status)", ["videoId": videoId, "status": status.rawValue])
    }

    func likeStatus(of videoId: String) async throws -> LikeStatus {
        let raw = try await ask("return await window.__ytmbar.likeStatus(videoId)", ["videoId": videoId]) as? String
        return raw.flatMap(LikeStatus.init(rawValue:)) ?? .indifferent
    }

    /// Creates a playlist, optionally with songs already in it, and returns its bare playlist ID.
    func createPlaylist(title: String, privacy: PlaylistPrivacy, videoIds: [String]) async throws -> String {
        let id = try await ask("return await window.__ytmbar.createPlaylist(title, privacy, videoIds)",
                               ["title": title, "privacy": privacy.rawValue, "videoIds": videoIds], retry: false) as? String
        guard let id, !id.isEmpty else { throw BridgeError.failed("YouTube Music couldn't create the playlist.") }
        return id
    }

    func editPlaylist(_ playlistID: String, title: String, privacy: PlaylistPrivacy) async throws {
        _ = try await ask("return await window.__ytmbar.editPlaylist(playlistId, title, privacy)",
                          ["playlistId": playlistID, "title": title, "privacy": privacy.rawValue])
    }

    func deletePlaylist(_ playlistID: String) async throws {
        _ = try await ask("return await window.__ytmbar.deletePlaylist(playlistId)", ["playlistId": playlistID])
    }

    /// The playlists the account can edit.
    func editablePlaylists() async throws -> [PlaylistChoice] {
        let rows = try await ask("return await window.__ytmbar.addablePlaylists()") as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return PlaylistChoice(id: id,
                                  title: row["title"] as? String ?? "",
                                  thumb: (row["thumb"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) })
        }
    }

    /// Every song in a playlist, by video ID.
    func videoIds(inPlaylist playlistID: String) async throws -> Set<String> {
        let ids = try await ask("return await window.__ytmbar.playlistVideoIds(id)", ["id": playlistID]) as? [String] ?? []
        return Set(ids)
    }

    /// Adds `videoId` to the playlist, or removes it when `include` is false.
    func setVideo(_ videoId: String, in playlistID: String, included include: Bool) async throws {
        _ = try await ask("return await window.__ytmbar.setInPlaylist(playlistId, videoId, include)",
                          ["playlistId": playlistID, "videoId": videoId, "include": include])
    }

    /// The signed-in Google account's display name.
    func accountName() async throws -> String {
        try await ask("return await window.__ytmbar.account()") as? String ?? ""
    }

    /// `retry` repeats a failed call once. Calls that aren't safe to repeat, such as creating a playlist, turn it off.
    private func ask(_ script: String, _ arguments: [String: Any] = [:], retry: Bool = true) async throws -> Any? {
        guard let webView else { throw BridgeError.notReady }
        try await waitForBridge(webView)
        do {
            return try await webView.callAsyncJavaScript(script, arguments: arguments, contentWorld: .page)
        } catch {
            guard retry else { throw error }
            // A signed-in page navigates once while it settles, which aborts in-flight fetches. Retry once.
            try await Task.sleep(for: .seconds(1.5))
            try await waitForBridge(webView)
            return try await webView.callAsyncJavaScript(script, arguments: arguments, contentWorld: .page)
        }
    }

    private static func track(_ row: [String: Any]) -> Track? {
        guard let id = row["videoId"] as? String else { return nil }
        return Track(videoId: id,
                     title: row["title"] as? String ?? "",
                     subtitle: row["subtitle"] as? String ?? "",
                     thumb: (row["thumb"] as? String).flatMap(URL.init(string:)),
                     likeStatus: (row["likeStatus"] as? String).flatMap(LikeStatus.init(rawValue:)))
    }

    private static func collection(_ row: [String: Any]) -> Playlist? {
        guard let id = row["id"] as? String else { return nil }
        return Playlist(id: id,
                          title: row["title"] as? String ?? "",
                          subtitle: row["subtitle"] as? String ?? "",
                          thumb: (row["thumb"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) })
    }

    /// Search needs the injected bridge and the page's InnerTube config, which appear a few seconds after launch.
    private func waitForBridge(_ webView: WKWebView) async throws {
        let check = "return !!(window.__ytmbar && window.ytcfg && window.ytcfg.get('INNERTUBE_API_KEY'))"
        for _ in 0..<40 {
            if let ready = try? await webView.callAsyncJavaScript(check, contentWorld: .page) as? Bool, ready { return }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw BridgeError.notReady
    }

    private func run(_ call: String) {
        webView?.evaluateJavaScript("window.__ytmbar && window.__ytmbar.\(call); null", completionHandler: nil)
    }

    private func callBridge(_ call: String, arguments: [String: Any]) {
        webView?.callAsyncJavaScript("window.__ytmbar && window.__ytmbar.\(call)", arguments: arguments,
                                     in: nil, in: .page, completionHandler: nil)
    }

    fileprivate func receive(_ body: Any) {
        guard let dict = body as? [String: Any], dict["type"] as? String == "state" else { return }
        let url: (Any?) -> URL? = { ($0 as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) } }
        var next = TrackState()
        next.videoId = dict["videoId"] as? String ?? ""
        next.title = dict["title"] as? String ?? ""
        next.artist = dict["artist"] as? String ?? ""
        next.album = dict["album"] as? String ?? ""
        next.artURL = url(dict["art"])
        next.playing = dict["playing"] as? Bool ?? false
        next.position = (dict["position"] as? NSNumber)?.doubleValue ?? 0
        next.positionDate = Date()
        next.duration = (dict["duration"] as? NSNumber)?.doubleValue ?? 0
        next.volume = (dict["volume"] as? NSNumber)?.doubleValue ?? 100
        next.signedIn = dict["signedIn"] as? Bool ?? false
        next.queue = (dict["queue"] as? [[String: Any]] ?? []).compactMap { q in
            guard let index = q["index"] as? Int else { return nil }
            return QueueItem(index: index,
                             title: q["title"] as? String ?? "",
                             artist: q["artist"] as? String ?? "",
                             thumb: url(q["thumb"]),
                             selected: q["selected"] as? Bool ?? false)
        }
        state = next
        onState?(next)
    }

    private static func isAllowed(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return true }
        return allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

extension PlayerController: WKNavigationDelegate, WKUIDelegate {
    // Links that leave YouTube/Google open in the default browser instead of inside the player.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url, !Self.isAllowed(url) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
    }

    // target=_blank and window.open: keep YouTube/Google pages in the player, send the rest out.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if Self.isAllowed(url) { webView.load(action.request) } else { NSWorkspace.shared.open(url) }
        }
        return nil
    }
}

enum BridgeError: LocalizedError {
    case notReady
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: "YouTube Music didn't finish loading. Check your connection and try again."
        case .failed(let message): message
        }
    }
}

/// WKUserContentController retains its handlers; this breaks the cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: PlayerController?
    init(_ target: PlayerController) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { target?.receive(body) }
    }
}
