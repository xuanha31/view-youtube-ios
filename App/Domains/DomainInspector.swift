import Foundation

/// Result of inspecting a domain: who owns it and a best-effort category,
/// to help decide Allow vs Block on a "later" domain (F8).
struct DomainInfo {
    let domain: String
    let registrar: String?
    let registrant: String?
    let createdDate: Date?
    let statuses: [String]
    /// Heuristic guess (ads/tracking/cdn/social/unknown) — not authoritative.
    let categoryHint: String
}

/// Fetches domain ownership via RDAP (the modern, JSON, no-auth replacement
/// for WHOIS — https://rdap.org/domain/{domain}) plus a local category guess.
struct DomainInspector {

    enum InspectError: Error { case badStatus(Int), decoding }

    func inspect(_ domain: String) async -> DomainInfo {
        let rdap = try? await fetchRDAP(domain)
        return DomainInfo(
            domain: domain,
            registrar: rdap?.registrar,
            registrant: rdap?.registrant,
            createdDate: rdap?.created,
            statuses: rdap?.statuses ?? [],
            categoryHint: Self.categoryHint(for: domain)
        )
    }

    // MARK: - RDAP

    private struct RDAPParsed {
        var registrar: String?
        var registrant: String?
        var created: Date?
        var statuses: [String] = []
    }

    private func fetchRDAP(_ domain: String) async throws -> RDAPParsed {
        let url = URL(string: "https://rdap.org/domain/\(domain)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw InspectError.badStatus(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InspectError.decoding
        }

        var parsed = RDAPParsed()
        parsed.statuses = (json["status"] as? [String]) ?? []

        // Registration date from events[].eventAction == "registration".
        if let events = json["events"] as? [[String: Any]] {
            for e in events where (e["eventAction"] as? String) == "registration" {
                if let s = e["eventDate"] as? String {
                    parsed.created = ISO8601DateFormatter().date(from: s)
                }
            }
        }

        // Registrar / registrant names from entities[].roles + vcardArray fn.
        if let entities = json["entities"] as? [[String: Any]] {
            for entity in entities {
                let roles = (entity["roles"] as? [String]) ?? []
                let name = Self.vcardName(entity["vcardArray"])
                if roles.contains("registrar"), parsed.registrar == nil { parsed.registrar = name }
                if roles.contains("registrant"), parsed.registrant == nil { parsed.registrant = name }
            }
        }
        return parsed
    }

    /// vcardArray is `["vcard", [ [name, {}, type, value], ... ]]`. Pull "fn".
    private static func vcardName(_ raw: Any?) -> String? {
        guard let array = raw as? [Any], array.count >= 2,
              let fields = array[1] as? [[Any]] else { return nil }
        for field in fields where (field.first as? String) == "fn" {
            return field.last as? String
        }
        return nil
    }

    // MARK: - Category heuristic

    private static let adKeywords =
        ["doubleclick", "googlesyndication", "googleadservices", "adservice",
         "pagead", "/ads", "adsystem", "advertising", "moatads", "criteo"]
    private static let trackKeywords =
        ["analytics", "tracking", "metric", "telemetry", "scorecardresearch",
         "mixpanel", "segment", "amplitude"]
    private static let cdnKeywords = ["cdn", "akamai", "cloudfront", "fastly", "edgecast"]
    private static let socialKeywords = ["facebook", "fbcdn", "instagram", "tiktok", "twitter"]

    static func categoryHint(for domain: String) -> String {
        let d = domain.lowercased()
        if adKeywords.contains(where: d.contains) { return "ads" }
        if trackKeywords.contains(where: d.contains) { return "tracking" }
        if socialKeywords.contains(where: d.contains) { return "social" }
        if cdnKeywords.contains(where: d.contains) { return "cdn" }
        return "unknown"
    }
}
