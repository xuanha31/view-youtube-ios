import Foundation

/// A domain seen in the NextDNS query log.
struct DomainLogEntry: Identifiable, Hashable {
    var id: String { domain }
    let domain: String
    let lastSeen: Date
    let count: Int
    /// Whether NextDNS already blocked it (from the log `status` field).
    let wasBlocked: Bool
    /// The user's manual decision (persisted locally for the "later" queue).
    var decision: Decision = .none

    enum Decision: String, Codable { case allow, block, later, none }
}

/// Decoding shape for NextDNS `/logs` responses.
/// [Unverified] Field names follow the NextDNS API as commonly documented;
/// verify against current docs when wiring the live endpoint.
struct NextDNSLogResponse: Decodable {
    struct Item: Decodable {
        let domain: String
        let timestamp: String?
        let status: String? // "default" | "blocked" | "allowed"
    }
    let data: [Item]
}
