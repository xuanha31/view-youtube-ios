import SwiftUI

/// Observable state shared between the SwiftUI screen and the web view.
final class YouTubeViewModel: ObservableObject {
    @Published var pageTitle: String = "YouTube"
    @Published var canGoBack = false
    @Published var canGoForward = false
    /// Set to request the web view navigate somewhere (search, home, etc.).
    @Published var pendingURL: URL?

    static let home = URL(string: "https://m.youtube.com")!

    func search(_ query: String) {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        pendingURL = URL(string: "https://m.youtube.com/results?search_query=\(q)")
    }

    func goHome() { pendingURL = YouTubeViewModel.home }
}

struct YouTubeView: View {
    @StateObject private var model = YouTubeViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            YouTubeWebView(url: YouTubeViewModel.home, model: model)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(model.pageTitle)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "Search YouTube")
                .onSubmit(of: .search) {
                    guard !searchText.isEmpty else { return }
                    model.search(searchText)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { model.goHome() } label: {
                            Image(systemName: "house.fill")
                        }
                    }
                }
        }
    }
}

#Preview {
    YouTubeView()
}
