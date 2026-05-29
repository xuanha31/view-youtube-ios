import SwiftUI

/// Observable state shared between the SwiftUI screen and the web view.
final class YouTubeViewModel: ObservableObject {
    @Published var pageTitle: String = "YouTube"
    @Published var canGoBack = false
    @Published var canGoForward = false
    /// Set to request the web view navigate somewhere (search, home, etc.).
    @Published var pendingURL: URL?
    /// Set to run a one-shot JS command in the web view (e.g. PiP).
    @Published var pendingJS: String?

    static let home = URL(string: "https://m.youtube.com")!

    func search(_ query: String) {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        pendingURL = URL(string: "https://m.youtube.com/results?search_query=\(q)")
    }

    func goHome() { pendingURL = YouTubeViewModel.home }

    /// Toggle Picture-in-Picture for the currently playing video.
    func togglePiP() { pendingJS = WebEnhancements.enterPiPJS }
}

struct YouTubeView: View {
    @StateObject private var model = YouTubeViewModel()

    var body: some View {
        // Full-bleed web view with no iOS browser chrome (no title bar / search
        // field / toolbar) so the app looks native — we rely on YouTube's own
        // top bar for home/search and on auto-PiP for background playback.
        YouTubeWebView(url: YouTubeViewModel.home, model: model)
            .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    YouTubeView()
}
