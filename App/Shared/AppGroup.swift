import Foundation

/// Shared container between the app and any future extension target.
/// Must match the App Group declared in ViewTube.entitlements / project.yml.
enum AppGroup {
    static let identifier = "group.com.viewtube.shared"

    /// Falls back to standard defaults if the App Group isn't provisioned
    /// (e.g. a free-cert build where the group capability is unavailable).
    static let defaults: UserDefaults =
        UserDefaults(suiteName: identifier) ?? .standard
}
