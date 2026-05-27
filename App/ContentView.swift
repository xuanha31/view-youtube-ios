import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            YouTubeView()
                .tabItem { Label("YouTube", systemImage: "play.rectangle.fill") }

            DomainsView()
                .tabItem { Label("Domains", systemImage: "shield.lefthalf.filled") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
}
