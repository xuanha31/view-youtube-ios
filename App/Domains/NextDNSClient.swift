import Foundation

/// Thin REST client for the NextDNS API.
///
/// [Unverified] Endpoint paths follow the commonly documented NextDNS API
/// shape (`api.nextdns.io/profiles/{id}/...`). Confirm against current docs
/// before relying on them (see docs Arch §11).
struct NextDNSClient {
    let profileID: String
    let apiKey: String

    private let base = URL(string: "https://api.nextdns.io")!

    enum ClientError: Error { case missingCredentials, badStatus(Int), decoding }

    // MARK: - Read

    /// Recent queried domains, de-duplicated with a seen count.
    func fetchRecentDomains(limit: Int = 200) async throws -> [DomainLogEntry] {
        let url = base.appendingPathComponent("profiles/\(profileID)/logs")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        let response: NextDNSLogResponse = try await get(comps.url!)
        let iso = ISO8601DateFormatter()

        // Collapse duplicate domains into one entry per host.
        var grouped: [String: (count: Int, last: Date, blocked: Bool)] = [:]
        for item in response.data {
            let date = item.timestamp.flatMap { iso.date(from: $0) } ?? Date()
            let blocked = (item.status == "blocked")
            if var g = grouped[item.domain] {
                g.count += 1
                g.last = max(g.last, date)
                g.blocked = g.blocked || blocked
                grouped[item.domain] = g
            } else {
                grouped[item.domain] = (1, date, blocked)
            }
        }
        return grouped
            .map { DomainLogEntry(domain: $0.key, lastSeen: $0.value.last,
                                  count: $0.value.count, wasBlocked: $0.value.blocked) }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: - Write (allow / deny)

    func allow(_ domain: String) async throws {
        try await post("profiles/\(profileID)/allowlist", body: ["id": domain, "active": true])
    }

    func block(_ domain: String) async throws {
        try await post("profiles/\(profileID)/denylist", body: ["id": domain, "active": true])
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request(url, method: "GET"))
        try check(response)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClientError.decoding
        }
        return decoded
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        var req = request(base.appendingPathComponent(path), method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: req)
        try check(response)
    }

    private func request(_ url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        return req
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw ClientError.badStatus(http.statusCode)
        }
    }
}
