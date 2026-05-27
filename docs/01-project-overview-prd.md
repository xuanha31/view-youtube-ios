# PRD — iOS Ad-Blocker & YouTube Player

- **Tài liệu:** Product Requirements Document
- **Ngày tạo:** 2026-05-27
- **Trạng thái:** DRAFT
- **Nền tảng:** iOS / iPadOS (không jailbreak)
- **Phân phối:** GitHub Actions build IPA → **SideStore** sideload (KHÔNG qua App Store / TestFlight)
- **UI:** SwiftUI (giao diện) + UIKit interop cho WebView/PiP
- **DNS:** dùng cả `NEDNSProxyProvider` + `NEPacketTunnelProvider` (xem ràng buộc §4.4)

---

## 1. Mục tiêu sản phẩm

Ứng dụng iOS cho phép người dùng:

1. Chặn quảng cáo ở tầng mạng cho các app khác (mức độ giới hạn — xem §4).
2. Xem YouTube không quảng cáo.
3. Phát YouTube dạng popup (Picture-in-Picture) và nghe khi khóa màn hình / chuyển app.

Tham chiếu sản phẩm tương tự: **Video Lite**, **AdGuard Pro**, **NextDNS**.

---

## 2. Phạm vi (Scope)

### 2.1 Trong phạm vi

| # | Tính năng | Module |
|---|---|---|
| F1 | Chặn ads theo domain cho mọi app (DNS filtering — **PA C: .mobileconfig → NextDNS DoH**) | DNS Profile + NextDNS |
| F2 | Trình duyệt YouTube không quảng cáo | WebView wrapper |
| F3 | Picture-in-Picture (popup video) | AVKit / WebView |
| F4 | Phát audio nền khi khóa màn hình | AVAudioSession |
| F5 | Cập nhật blocklist (EasyList / AdGuard DNS filter) | Blocklist Manager |
| F6 | Bật/tắt chặn ads, chọn bộ lọc | Settings |
| **F7** | **Quản lý domain thủ công:** xem domain iOS đã truy cập → Allow (whitelist) / Block / Để sau | NextDNS API |
| **F8** | **Tra cứu domain "là gì"** (whois, category, ai sở hữu) — option xem sau | Domain Inspector |

### 2.2 Ngoài phạm vi (Out of scope)

- Chặn ads bên trong UI của app khác (sandbox iOS không cho phép — xem §4.1).
- **Popup real-time hỏi Accept/Block ngay khi truy cập domain** (cần PA A / NetworkExtension local → cần account trả phí; đã loại). F7 dùng mô hình review-sau.
- Giải mã HTTPS / MITM để lọc theo đường dẫn URL (Apple cấm, rủi ro bảo mật).
- Tải video YouTube về máy (vùng xám pháp lý cao).
- Jailbreak.

### 2.3 Phụ thuộc bên ngoài
- **Tài khoản NextDNS (free)** — bắt buộc cho F1, F7, F8. App lưu API key/profile ID của người dùng.

---

## 3. Yêu cầu chức năng chi tiết

### F1 — DNS Ad Filtering (PA C — .mobileconfig)
- App tạo & hướng dẫn cài **DNS config profile (.mobileconfig)** trỏ DNS hệ thống tới **NextDNS DoH** (profile riêng của người dùng).
- NextDNS làm "người gác": chặn domain theo blocklist (AdGuard/EasyList có sẵn) + denylist của người dùng.
- App KHÔNG tự phân giải DNS (không có local interceptor) → không cần entitlement.

### F7 — Quản lý domain thủ công (mô hình "xem log → quyết định")

> Không phải popup real-time. iOS không dừng request để hỏi (chỉ PA A local mới làm được). Đây là mô hình **review sau**: domain hiện trong log → người dùng quyết định.

- Lấy **query log** (domain iOS đã truy cập) qua **NextDNS API**.
- Mỗi domain có 3 hành động:
  - **Allow** → thêm vào allowlist NextDNS (luôn cho qua).
  - **Block** → thêm vào denylist NextDNS (lần sau iOS không vào được).
  - **Để sau** → đánh dấu "chờ xem xét", chưa quyết.
- Đồng bộ allow/deny lên NextDNS qua API → có hiệu lực toàn thiết bị.

### F8 — Tra cứu domain "là gì" (option xem sau)
- Với domain "Để sau": tra **category (NextDNS), WHOIS, tổ chức sở hữu** để biết domain đó của ai/dùng làm gì trước khi quyết Allow/Block.

### F2 — YouTube không quảng cáo
- App nhúng `WKWebView` load `https://m.youtube.com`.
- Áp `WKContentRuleList` chặn request ads + inject `WKUserScript` xóa/skip ad trong DOM.
- Điều hướng: tìm kiếm, xem, danh sách phát.

### F3 — Picture-in-Picture
- Nút popup → video tách thành cửa sổ PiP nổi.
- Hoạt động khi chuyển sang app khác.

### F4 — Background Audio
- Tiếp tục phát tiếng khi khóa màn hình hoặc chuyển app.
- Hiển thị điều khiển trên Lock Screen / Control Center (Now Playing).

### F5 — Quản lý Blocklist
- Tải & cập nhật định kỳ các bộ lọc công khai (EasyList, AdGuard DNS).
- Cho phép thêm domain tùy chỉnh (allowlist / blocklist).

### F6 — Settings
- Bật/tắt từng tính năng, chọn bộ lọc, xem thống kê, whitelist domain.

---

## 4. Ràng buộc kỹ thuật & Rủi ro (BẮT BUỘC ĐỌC)

### 4.1 Giới hạn cứng của iOS

> [Unverified — dựa trên mô hình sandbox iOS] App KHÔNG thể đọc/sửa nội dung hiển thị bên trong app khác. "Chặn sạch ads trong mọi app" là KHÔNG khả thi trên iOS không jailbreak.

- DNS filtering chỉ chặn được **request tới domain ads**, không xóa được khoảng trống UI.
- Ad **cùng domain với nội dung chính** (Facebook `fbcdn`, TikTok CDN, YouTube `googlevideo.com`) → không tách được → DNS filtering gần như vô hiệu với các app này.
- HTTPS che đường dẫn → chỉ lọc được ở mức **domain/IP (SNI)**, không lọc theo từng URL path.

### 4.2 Phân phối qua SideStore (không App Store)

Do phân phối bằng GitHub build + SideStore, **không còn rủi ro App Store review** (guideline 4.3, bản quyền Google) — đây là lợi thế lớn. Nhưng phát sinh ràng buộc free-cert:

| Ràng buộc (free Apple ID) | Ảnh hưởng |
|---|---|
| App hết hạn sau **7 ngày** | Phải refresh định kỳ qua SideStore (auto-refresh nếu cấu hình) |
| Tối đa **3 app** sideload | Hạn chế số app cùng lúc |
| **Không có entitlement `NetworkExtension`** | Target DNS Extension **không ký được** — xem §4.4 |
| ToS YouTube | Vẫn vi phạm điều khoản dịch vụ YouTube (chấp nhận vì dùng cá nhân) |

> Tài khoản Apple Developer trả phí ($99/năm): app hết hạn 1 năm, gỡ giới hạn 3 app, **và** mở khóa entitlement `NetworkExtension`.

### 4.4 Xung đột SideStore × DNS Extension (QUYẾT ĐỊNH CẦN CHỐT)

> [Inference — dựa trên cơ chế provisioning của Apple] Entitlement `com.apple.developer.networking.networkextension` là **restricted**, free personal team (SideStore) KHÔNG cấp được. Do đó Phase 2 (DNS Proxy + Packet Tunnel) nhiều khả năng KHÔNG chạy được nếu chỉ dùng free cert.

**3 phương án cho DNS filtering:**

| PA | Cách làm | Cần entitlement? | Hợp với SideStore free? |
|----|----------|------------------|--------------------------|
| **A** | `NEDNSProxyProvider` + `NEPacketTunnelProvider` (như §3) | ✅ Có (restricted) | ❌ Cần dev trả phí |
| **B** | Tài khoản dev trả phí $99 → ký Network Extension bình thường | ✅ Có | ✅ (đã trả phí) |
| **C** | App tạo & cài **DNS config profile (.mobileconfig)** trỏ NextDNS/AdGuard DoH | ❌ Không | ✅ Chạy ngay |

→ **Khuyến nghị:** Phase 1 (YouTube) chạy tốt với SideStore free. Phase 2 dùng **PA C** trước (không cần trả phí), nâng lên **PA A/B** nếu sau này có tài khoản trả phí.

### 4.3 Rủi ro bảo trì
- YouTube đổi cấu trúc HTML/class liên tục → JS chặn ads hỏng thường xuyên, cần cập nhật.

---

## 5. Ưu tiên triển khai (đề xuất)

1. **Phase 1 — YouTube WebView** (F2, F3, F4): giá trị cao nhất, khả thi chắc chắn.
2. **Phase 2 — DNS Filtering** (F1, F5): chặn ads mạng diện rộng (hiệu quả vừa).
3. **Phase 3 — Settings & Polish** (F6).

---

## 6. Quyết định đã chốt

- ✅ Phân phối: GitHub Actions build IPA → SideStore (không App Store/TestFlight).
- ✅ UI: SwiftUI + UIKit interop.
- ✅ DNS: dùng cả DNS Proxy + Packet Tunnel (PA A) — **với điều kiện** có entitlement (§4.4).

## 7. Câu hỏi chưa giải quyết

- Có sẵn sàng mua tài khoản Apple Developer $99/năm không? → quyết định Phase 2 dùng PA A/B (Network Extension) hay PA C (.mobileconfig). **Nếu chỉ free cert → DNS Extension không chạy, phải dùng PA C.**
- Có cần đồng bộ cài đặt qua iCloud không?
- Có cấu hình SideStore auto-refresh để tránh app hết hạn 7 ngày không?
