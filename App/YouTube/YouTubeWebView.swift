import SwiftUI
import WebKit

/// SwiftUI wrapper around a `WKWebView` configured for ad-free YouTube with
/// inline playback and Picture-in-Picture. UIKit interop is required because
/// WebKit + AVKit PiP have no native SwiftUI equivalents.
struct YouTubeWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var model: YouTubeViewModel

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Playback enhancements (always on): background audio + hide "Open app".
        config.userContentController.addUserScript(WebEnhancements.backgroundPlayScript())
        config.userContentController.addUserScript(WebEnhancements.hideOpenAppScript())

        // Ad blocking can be turned off in Settings to isolate playback issues
        // (YouTube's anti-adblock can refuse playback when ads are blocked).
        let adBlockEnabled = AppGroup.defaults.object(forKey: "adBlockEnabled") as? Bool ?? true

        // Layer 2 ad blocking: inject DOM cleanup script.
        if adBlockEnabled {
            config.userContentController.addUserScript(AdBlocker.makeUserScript())
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Use the WebView's native Safari user-agent. A hardcoded/mismatched UA
        // makes YouTube reject playback ("Playback ID" error); letting WebKit
        // report its real version is what lets the HTML5 player work, the same
        // way it does in Safari.

        context.coordinator.attach(webView)

        // Layer 1 ad blocking: add the compiled content rule list, then load.
        Task {
            if adBlockEnabled, let ruleList = await AdBlocker.contentRuleList() {
                config.userContentController.add(ruleList)
            }
            await MainActor.run { webView.load(URLRequest(url: url)) }
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Navigation is driven by the model's command queue (search, home...).
        if let pending = model.pendingURL, webView.url != pending {
            webView.load(URLRequest(url: pending))
            DispatchQueue.main.async { model.pendingURL = nil }
        }
        // One-shot JS commands (e.g. enter Picture-in-Picture).
        if let js = model.pendingJS {
            webView.evaluateJavaScript(js)
            DispatchQueue.main.async { model.pendingJS = nil }
        }
    }
}
