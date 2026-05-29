import WebKit
import UIKit

/// Bridges the WKWebView lifecycle to the SwiftUI model and routes Lock Screen
/// transport commands back into the web player via JavaScript.
final class WebViewCoordinator: NSObject, WKNavigationDelegate {
    private let model: YouTubeViewModel
    private weak var webView: WKWebView?

    init(model: YouTubeViewModel) {
        self.model = model
        super.init()
        // Route Lock Screen / Control Center presses to the <video> element.
        AudioSessionManager.shared.onCommand = { [weak self] command in
            self?.handle(command)
        }
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        // Auto-enter PiP when the app is backgrounded (e.g. screen lock) so
        // audio keeps playing without the user tapping the PiP button. We use
        // didEnterBackground rather than willResignActive so that transient
        // foreground losses (Control Center, notification banner) don't pop PiP.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
    }

    @objc private func appDidEnterBackground() {
        webView?.evaluateJavaScript(WebEnhancements.autoEnterPiPJS)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        model.canGoBack = webView.canGoBack
        model.canGoForward = webView.canGoForward
        let title = webView.title ?? "YouTube"
        model.pageTitle = title
        AudioSessionManager.shared.updateNowPlaying(title: title, isPlaying: true)
    }

    // MARK: - Transport command -> JS

    private func handle(_ command: AudioSessionManager.TransportCommand) {
        let js: String
        switch command {
        case .play:     js = "document.querySelector('video')?.play();"
        case .pause:    js = "document.querySelector('video')?.pause();"
        case .next:     js = "document.querySelector('.ytp-next-button')?.click();"
        case .previous: js = "document.querySelector('.ytp-prev-button')?.click();"
        }
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js)
        }
    }
}
