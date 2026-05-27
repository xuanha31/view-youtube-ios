import Foundation

/// F7 view model: fetches the domain log and applies Allow / Block / Later
/// decisions. "Later" is stored locally (App Group); Allow/Block sync to
/// NextDNS so they take effect device-wide on the next request.
@MainActor
final class DomainManager: ObservableObject {
    @Published var domains: [DomainLogEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let laterKey = "domains.later"

    private var client: NextDNSClient? {
        let id = AppGroup.defaults.string(forKey: "nextDNSProfileID") ?? ""
        let key = KeychainStore.get("nextDNSApiKey") ?? ""
        guard !id.isEmpty, !key.isEmpty else { return nil }
        return NextDNSClient(profileID: id, apiKey: key)
    }

    var isConfigured: Bool { client != nil }

    // MARK: - Load

    func refresh() async {
        guard let client else {
            errorMessage = "Chưa cấu hình NextDNS (Settings → NextDNS API key)."
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            var fetched = try await client.fetchRecentDomains()
            let laterSet = loadLater()
            for i in fetched.indices where laterSet.contains(fetched[i].domain) {
                fetched[i].decision = .later
            }
            domains = fetched
        } catch {
            errorMessage = "Không tải được log: \(error)"
        }
    }

    // MARK: - Decisions

    func allow(_ entry: DomainLogEntry) async { await apply(entry, .allow) }
    func block(_ entry: DomainLogEntry) async { await apply(entry, .block) }

    func markLater(_ entry: DomainLogEntry) {
        var set = loadLater(); set.insert(entry.domain); saveLater(set)
        update(entry.domain, to: .later)
    }

    private func apply(_ entry: DomainLogEntry, _ decision: DomainLogEntry.Decision) async {
        guard let client else { return }
        do {
            switch decision {
            case .allow: try await client.allow(entry.domain)
            case .block: try await client.block(entry.domain)
            default: break
            }
            // Remove from the "later" queue once a real decision is made.
            var set = loadLater(); set.remove(entry.domain); saveLater(set)
            update(entry.domain, to: decision)
        } catch {
            errorMessage = "Cập nhật thất bại: \(error)"
        }
    }

    private func update(_ domain: String, to decision: DomainLogEntry.Decision) {
        if let i = domains.firstIndex(where: { $0.domain == domain }) {
            domains[i].decision = decision
        }
    }

    // MARK: - Later queue persistence

    private func loadLater() -> Set<String> {
        Set(AppGroup.defaults.stringArray(forKey: laterKey) ?? [])
    }
    private func saveLater(_ set: Set<String>) {
        AppGroup.defaults.set(Array(set), forKey: laterKey)
    }
}
