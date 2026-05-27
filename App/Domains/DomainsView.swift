import SwiftUI

/// F7 screen: review domains iOS has accessed, then Allow / Block / Later.
struct DomainsView: View {
    @StateObject private var manager = DomainManager()
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable { case all = "Tất cả", later = "Để sau", blocked = "Đã chặn" }

    private var visible: [DomainLogEntry] {
        switch filter {
        case .all:     return manager.domains
        case .later:   return manager.domains.filter { $0.decision == .later }
        case .blocked: return manager.domains.filter { $0.decision == .block || $0.wasBlocked }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !manager.isConfigured {
                    notConfigured
                } else {
                    list
                }
            }
            .navigationTitle("Domains")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await manager.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { if manager.isConfigured { await manager.refresh() } }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if manager.isLoading && manager.domains.isEmpty {
                ProgressView().frame(maxHeight: .infinity)
            } else {
                List(visible) { entry in
                    NavigationLink {
                        DomainDetailView(entry: entry, manager: manager)
                    } label: {
                        DomainRow(entry: entry, manager: manager)
                    }
                }
                .listStyle(.plain)
                .refreshable { await manager.refresh() }
                .overlay {
                    if let msg = manager.errorMessage, manager.domains.isEmpty {
                        ContentUnavailableView("Không có dữ liệu", systemImage: "wifi.slash",
                                               description: Text(msg))
                    }
                }
            }
        }
    }

    private var notConfigured: some View {
        ContentUnavailableView {
            Label("Chưa kết nối NextDNS", systemImage: "key.slash")
        } description: {
            Text("Vào Settings → nhập NextDNS Profile ID + API key để xem & quản lý domain.")
        }
    }
}

private struct DomainRow: View {
    let entry: DomainLogEntry
    @ObservedObject var manager: DomainManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.domain).font(.callout.weight(.medium)).lineLimit(1)
                Spacer()
                badge
            }
            Text("\(entry.count) lần · \(entry.lastSeen.formatted(.relative(presentation: .named)))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { Task { await manager.block(entry) } } label: {
                Label("Block", systemImage: "hand.raised.fill")
            }
            Button { Task { await manager.allow(entry) } } label: {
                Label("Allow", systemImage: "checkmark")
            }.tint(.green)
            Button { manager.markLater(entry) } label: {
                Label("Để sau", systemImage: "clock")
            }.tint(.orange)
        }
    }

    @ViewBuilder private var badge: some View {
        switch entry.decision {
        case .allow: tag("Allow", .green)
        case .block: tag("Block", .red)
        case .later: tag("Để sau", .orange)
        case .none:  if entry.wasBlocked { tag("Blocked", .red.opacity(0.6)) }
        }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15)).foregroundStyle(color)
            .clipShape(Capsule())
    }
}
