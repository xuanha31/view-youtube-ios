# Tasks Backlog — iOS Ad-Blocker & YouTube Player

- **Ngày tạo:** 2026-05-27
- **Liên quan:** [PRD](./01-project-overview-prd.md) · [Architecture](./02-system-architecture.md)
- **Quy ước:** `[ ]` chưa làm · `[~]` đang làm · `[x]` xong · Ưu tiên P0 (cao) → P2 (thấp)

---

## Phase 0 — Khởi tạo dự án

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T0.1 | Tạo Xcode project **SwiftUI**, bundle ID, team, signing | P0 | — | [ ] |
| T0.2 | Thiết lập App Group chia sẻ dữ liệu app ↔ extension | P0 | T0.1 | [ ] |
| T0.3 | Cấu trúc thư mục theo Architecture §5 (App / Extension / Shared) | P0 | T0.1 | [ ] |
| T0.4 | GitHub Actions: build IPA (macos-latest) + upload Release | P0 | T0.1 | [ ] |
| T0.5 | Cài thử qua SideStore + cấu hình auto-refresh (tránh hết hạn 7 ngày) | P0 | T0.4 | [ ] |

---

## Phase 1 — YouTube WebView (F2, F3, F4) — *giá trị cao nhất*

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T1.1 | Tạo màn hình WebView load `m.youtube.com` | P0 | T0.x | [ ] |
| T1.2 | Cấu hình `WKWebViewConfiguration` (inline + PiP + autoplay) | P0 | T1.1 | [ ] |
| T1.3 | Inject `WKUserScript` xóa DOM ads + auto-skip video ad | P0 | T1.2 | [ ] |
| T1.4 | Thêm `WKContentRuleList` chặn request domain ads trong webview | P1 | T1.2 | [ ] |
| T1.5 | Bật `AVAudioSession(.playback)` — nghe khi khóa màn hình | P0 | T1.1 | [ ] |
| T1.6 | Background Modes (audio) + giữ phát khi chuyển app | P0 | T1.5 | [ ] |
| T1.7 | Picture-in-Picture: nút bật + duy trì khi rời app | P0 | T1.2 | [ ] |
| T1.8 | Now Playing info + điều khiển Lock Screen / Control Center | P1 | T1.5 | [ ] |
| T1.9 | Điều hướng cơ bản (back/forward, reload, tìm kiếm) | P1 | T1.1 | [ ] |
| T1.10 | Kiểm thử ads bị chặn trên video thật + cập nhật selector | P0 | T1.3 | [ ] |

---

## Phase 2 — DNS Ad Filtering: PA C .mobileconfig (F1, F5)

> **CHỐT:** PA C (.mobileconfig → NextDNS DoH). Không mua account, không NetworkExtension. PRD §4.4, Arch §10.

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T2.1 | Onboarding NextDNS: nhập/lưu profile ID + API key (Keychain) | P0 | T0.2 | [ ] |
| T2.2 | Sinh `.mobileconfig` DoH trỏ `dns.nextdns.io/<profileID>` | P0 | T2.1 | [ ] |
| T2.3 | Luồng cài profile + hướng dẫn (Settings → Profile Downloaded) | P0 | T2.2 | [ ] |
| T2.4 | Phát hiện trạng thái profile đã cài / DNS đang hoạt động | P1 | T2.3 | [ ] |
| T2.5 | Bật blocklist ads NextDNS (AdGuard/EasyList) qua API | P1 | T2.1 | [ ] |

## Phase 2b — Quản lý domain thủ công (F7) — *tính năng bạn yêu cầu*

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T7.1 | `DomainManagerService`: gọi NextDNS API lấy query log | P0 | T2.1 | [ ] |
| T7.2 | Màn hình "Domain đã truy cập" — list domain + thời gian + trạng thái | P0 | T7.1 | [ ] |
| T7.3 | Hành động **Allow** → thêm allowlist NextDNS (API) | P0 | T7.1 | [ ] |
| T7.4 | Hành động **Block** → thêm denylist NextDNS (API) | P0 | T7.1 | [ ] |
| T7.5 | Hành động **Để sau** → đánh dấu local (App Group), tab riêng | P1 | T7.2 | [ ] |
| T7.6 | Quản lý allowlist/denylist hiện có (xem, gỡ) | P1 | T7.3,T7.4 | [ ] |
| T7.7 | Lọc/tìm kiếm domain, gộp domain trùng | P2 | T7.2 | [ ] |

## Phase 2c — Domain Inspector (F8) — *option xem sau*

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T8.1 | `DomainInspector`: lấy category domain từ NextDNS log | P2 | T7.1 | [ ] |
| T8.2 | Tra WHOIS (tổ chức sở hữu, ngày tạo) cho domain "Để sau" | P2 | T7.5 | [ ] |
| T8.3 | UI chi tiết domain: category + whois + gợi ý Allow/Block | P2 | T8.1,T8.2 | [ ] |

---

## Phase 3 — Settings & Polish (F6)

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T3.1 | Màn hình Settings: bật/tắt từng tính năng | P1 | Phase 1,2 | [ ] |
| T3.2 | Chọn bộ lọc blocklist | P2 | T2.5 | [ ] |
| T3.3 | Dashboard thống kê (requests blocked, domains) | P2 | T2.8 | [ ] |
| T3.4 | Dark mode + tinh chỉnh UX | P2 | — | [ ] |
| T3.5 | Onboarding hướng dẫn cài VPN profile | P1 | T2.9 | [ ] |

---

## Phase 4 — Phân phối (GitHub + SideStore)

| ID | Task | Ưu tiên | Phụ thuộc | Trạng thái |
|----|------|---------|-----------|------------|
| T4.1 | Hoàn thiện GitHub Actions build → Release IPA tự động | P0 | T0.4 | [ ] |
| T4.2 | Tạo SideStore source (JSON) trỏ tới Release để auto-update | P1 | T4.1 | [ ] |
| T4.3 | Kiểm thử trên thiết bị thật (iPhone + iPad) qua SideStore | P0 | Phase 1,2 | [ ] |
| T4.4 | README hướng dẫn cài qua SideStore + lưu ý hết hạn 7 ngày | P1 | T4.2 | [ ] |

---

## Cảnh báo xuyên suốt (nhắc khi làm)

- **T-RISK-1:** DNS filtering KHÔNG chặn được ads cùng domain nội dung (FB/TikTok/YouTube app). Đặt kỳ vọng đúng — PRD §4.1.
- **T-RISK-2:** JS chặn ads YouTube cần cập nhật thường xuyên (T1.10 lặp lại định kỳ).
- **T-RISK-3:** Free cert SideStore KHÔNG có entitlement NetworkExtension → PA A (DNS Extension) không chạy, phải dùng PA C. Chốt T2.0 sớm — PRD §4.4.
- **T-RISK-4:** App hết hạn 7 ngày (free cert) → cấu hình SideStore auto-refresh (T0.5).
- **T-RISK-5:** F7 KHÔNG chặn real-time — mô hình review-sau qua NextDNS log (có độ trễ). Đặt kỳ vọng đúng — PRD §F7.

---

## Đề xuất thứ tự thực thi

`Phase 0 → Phase 1 (MVP demo được) → Phase 2 (DNS) → Phase 2b (quản lý domain) → Phase 2c → Phase 3 → Phase 4`

MVP nhỏ nhất đáng dùng = **T0.1–T0.5 + T1.1–T1.7** (YouTube không ads + PiP + nghe nền, cài được qua SideStore).

## Lưu ý về F7 (quản lý domain)

- **Không phải popup real-time** — iOS không dừng request để hỏi. Mô hình là: domain hiện trong log NextDNS (có độ trễ) → bạn Allow/Block/Để-sau → áp dụng cho lần sau (T-RISK-5).
- Phụ thuộc **tài khoản NextDNS free** + API key (T2.1 phải xong trước).
- [Unverified] Endpoint NextDNS API cần kiểm chứng với tài liệu hiện hành khi code (Arch §11).
