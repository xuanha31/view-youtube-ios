import Foundation

/// Builds an iOS DNS configuration profile (`.mobileconfig`) that routes all
/// system DNS through the user's NextDNS profile over DNS-over-HTTPS.
///
/// This is PA C (see docs §4.4): no NetworkExtension entitlement required, so
/// it works with a free SideStore certificate. NextDNS enforces the actual
/// ad blocking + allow/deny lists server-side.
enum MobileConfigGenerator {

    /// Produces the profile XML for a given NextDNS profile id (e.g. "abc123").
    static func makeProfile(nextDNSProfileID: String,
                            deviceName: String = "ViewTube") -> String {
        let doh = "https://dns.nextdns.io/\(nextDNSProfileID)"
        let payloadUUID = UUID().uuidString
        let profileUUID = UUID().uuidString
        let bundleID = "com.viewtube.dns"

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadType</key>
                    <string>com.apple.dnsSettings.managed</string>
                    <key>PayloadIdentifier</key>
                    <string>\(bundleID).\(payloadUUID)</string>
                    <key>PayloadUUID</key>
                    <string>\(payloadUUID)</string>
                    <key>PayloadDisplayName</key>
                    <string>ViewTube DNS (NextDNS)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>DNSSettings</key>
                    <dict>
                        <key>DNSProtocol</key>
                        <string>HTTPS</string>
                        <key>ServerURL</key>
                        <string>\(doh)</string>
                    </dict>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>ViewTube Ad-Block DNS</string>
            <key>PayloadIdentifier</key>
            <string>\(bundleID)</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(profileUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadDescription</key>
            <string>Routes DNS through your NextDNS profile to block ads.</string>
        </dict>
        </plist>
        """
    }

    /// Writes the profile to a temp file and returns its URL for installation
    /// (iOS opens .mobileconfig files in Settings to install the profile).
    static func writeProfile(nextDNSProfileID: String) throws -> URL {
        let xml = makeProfile(nextDNSProfileID: nextDNSProfileID)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewTube-DNS.mobileconfig")
        try xml.data(using: .utf8)?.write(to: url)
        return url
    }
}
