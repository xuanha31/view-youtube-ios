import SwiftUI

/// F8 screen: shows who owns a domain (RDAP/WHOIS) + a category hint, with
/// Allow / Block actions inline so the user can decide on a "later" domain.
struct DomainDetailView: View {
    let entry: DomainLogEntry
    @ObservedObject var manager: DomainManager

    @State private var info: DomainInfo?
    @State private var isLoading = true

    private let inspector = DomainInspector()

    var body: some View {
        Form {
            Section("Domain") {
                LabeledContent("Tên miền", value: entry.domain)
                LabeledContent("Số lần truy cập", value: "\(entry.count)")
                LabeledContent("Gần nhất",
                               value: entry.lastSeen.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                if isLoading {
                    HStack { ProgressView(); Text("Đang tra cứu...").foregroundStyle(.secondary) }
                } else if let info {
                    LabeledContent("Phân loại (đoán)", value: info.categoryHint)
                    if let r = info.registrar { LabeledContent("Nhà đăng ký", value: r) }
                    if let o = info.registrant { LabeledContent("Chủ sở hữu", value: o) }
                    if let c = info.createdDate {
                        LabeledContent("Ngày tạo",
                                       value: c.formatted(date: .abbreviated, time: .omitted))
                    }
                    if !info.statuses.isEmpty {
                        LabeledContent("Trạng thái", value: info.statuses.joined(separator: ", "))
                    }
                } else {
                    Text("Không tra cứu được thông tin domain.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Domain là gì?")
            } footer: {
                Text("Nguồn: RDAP (rdap.org). 'Phân loại' chỉ là gợi ý dựa trên tên miền, không chắc chắn.")
            }

            Section("Quyết định") {
                Button {
                    Task { await manager.allow(entry) }
                } label: { Label("Allow (cho phép)", systemImage: "checkmark.circle.fill") }
                    .tint(.green)

                Button(role: .destructive) {
                    Task { await manager.block(entry) }
                } label: { Label("Block (chặn)", systemImage: "hand.raised.fill") }
            }
        }
        .navigationTitle("Chi tiết domain")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            info = await inspector.inspect(entry.domain)
            isLoading = false
        }
    }
}
