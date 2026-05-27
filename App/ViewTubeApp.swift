import SwiftUI

@main
struct ViewTubeApp: App {
    init() {
        // Enable background audio as early as possible so playback survives
        // screen lock / app switch from the very first video.
        AudioSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
