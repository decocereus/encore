import SwiftUI
import WebKit

/// Google's sign-in page, shown inside the drawer. It writes into the current account's cookie store,
/// so the player is signed in as soon as Google sends the page back to YouTube Music.
struct SignInSheet: View {
    let model: AppModel
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                GlyphButton(symbol: "xmark", label: "Cancel sign-in", size: 32, font: .callout.weight(.semibold)) {
                    model.signingIn = false
                }
                .keyboardShortcut(.cancelAction)
                Text("Sign in with Google").font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                if loading { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, 12)
            .frame(height: 52)

            if let store = model.player.dataStore {
                SignInWebView(store: store, loading: $loading, onFinish: model.finishSignIn)
                    .clipShape(.rect(cornerRadius: 18))
                    .padding([.horizontal, .bottom], 8)
            }
        }
    }
}

private struct SignInWebView: NSViewRepresentable {
    let store: WKWebsiteDataStore
    @Binding var loading: Bool
    let onFinish: () -> Void

    private static let start = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F")!

    /// Passkeys for google.com only work in apps Apple entitles as web browsers. Hiding WebAuthn makes Google
    /// offer its other methods (phone prompt, password) instead of a passkey request that would fail.
    private static let hidePasskeys = """
    (() => {
      try { Object.defineProperty(window, 'PublicKeyCredential', { value: undefined, configurable: true }); } catch (e) {}
      const creds = navigator.credentials;
      if (!creds) return;
      const refuse = () => Promise.reject(new DOMException('Passkeys are not available here.', 'NotAllowedError'));
      const get = creds.get && creds.get.bind(creds), create = creds.create && creds.create.bind(creds);
      creds.get = (options) => options && options.publicKey ? refuse() : get(options);
      creds.create = (options) => options && options.publicKey ? refuse() : create(options);
    })();
    """

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        config.userContentController.addUserScript(
            WKUserScript(source: Self.hidePasskeys, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = PlayerController.userAgent
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        view.load(URLRequest(url: Self.start))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: SignInWebView
        private var finished = false

        init(_ parent: SignInWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            // youtube.com/signin sets the YouTube cookies, then redirects to the player: that's the finish line.
            if action.targetFrame?.isMainFrame == true, action.request.url?.host == "music.youtube.com" {
                decisionHandler(.cancel)
                if !finished {
                    finished = true
                    parent.onFinish()
                }
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.loading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.loading = false
            // The panel never activates the app, so give the page keyboard focus explicitly.
            webView.window?.makeFirstResponder(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
        }

        // Help and privacy links open in the user's browser; Google's own sign-in steps stay here.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url {
                if url.host?.hasSuffix("accounts.google.com") == true { webView.load(action.request) } else { NSWorkspace.shared.open(url) }
            }
            return nil
        }
    }
}
