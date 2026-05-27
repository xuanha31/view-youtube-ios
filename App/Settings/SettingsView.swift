import SwiftUI

struct SettingsView: View {
    @AppStorage("nextDNSProfileID", store: AppGroup.defaults)
    private var profileID = ""
    @State private var apiKey = KeychainStore.get("nextDNSApiKey") ?? ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Profile ID", text: $profileID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API key", text: $apiKey)
                    Button("Lưu") {
                        KeychainStore.set(apiKey, for: "nextDNSApiKey")
                        saved = true
                    }
                    if saved {
                        Label("Đã lưu", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.footnote)
                    }
                } header: {
                    Text("NextDNS")
                } footer: {
                    Text("Đăng ký miễn phí tại nextdns.io. Profile ID + API key dùng cho "
                         + "chặn ads (DNS) và quản lý domain (tab Domains).")
                }

                Section("Ad-Block DNS") {
                    NavigationLink {
                        DNSProfileView()
                    } label: {
                        Label("Cài / quản lý DNS profile", systemImage: "shield.fill")
                    }
                }

                Section("Giới hạn đã biết") {
                    bullet("Chỉ chặn ads YouTube trong app này (tab YouTube), "
                           + "không can thiệp app YouTube chính thức.")
                    bullet("DNS chỉ chặn theo domain — không chặn ads cùng domain "
                           + "nội dung (FB/TikTok/YouTube native).")
                    bullet("Quản lý domain là xem-log-rồi-quyết, không phải popup real-time.")
                    bullet("App hết hạn sau 7 ngày (free cert) — refresh qua SideStore.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote).labelStyle(.titleAndIcon)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
