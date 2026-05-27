import SwiftUI
import SafariServices

/// Lets the user generate and install the NextDNS .mobileconfig profile.
/// After install, iOS routes DNS through NextDNS and ad domains are blocked.
struct DNSProfileView: View {
    @AppStorage("nextDNSProfileID", store: AppGroup.defaults)
    private var profileID = ""

    @State private var shareURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("NextDNS Profile") {
                TextField("Profile ID (e.g. abc123)", text: $profileID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Lấy Profile ID tại my.nextdns.io → Setup.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button {
                    installProfile()
                } label: {
                    Label("Cài DNS profile", systemImage: "square.and.arrow.down")
                }
                .disabled(profileID.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Sau khi bấm, iOS sẽ mở Settings → Profile Downloaded để bạn cài. "
                     + "DNS sẽ đi qua NextDNS và chặn quảng cáo cho mọi app.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Ad-Block DNS")
        .sheet(item: $shareURL) { url in
            ActivityView(activityItems: [url])
        }
    }

    private func installProfile() {
        let id = profileID.trimmingCharacters(in: .whitespaces)
        do {
            let url = try MobileConfigGenerator.writeProfile(nextDNSProfileID: id)
            // Opening the file URL hands it to iOS, which installs profiles.
            shareURL = url
        } catch {
            errorMessage = "Không tạo được profile: \(error.localizedDescription)"
        }
    }
}

// Allow URL to be used with .sheet(item:).
extension URL: Identifiable {
    public var id: String { absoluteString }
}

/// UIKit share sheet bridge for presenting the generated profile.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
