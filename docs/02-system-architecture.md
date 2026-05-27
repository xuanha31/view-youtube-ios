# System Architecture — iOS Ad-Blocker & YouTube Player

- **Ngày tạo:** 2026-05-27
- **Trạng thái:** DRAFT
- **Liên quan:** [PRD](./01-project-overview-prd.md)

---

## 1. Tổng quan kiến trúc

App gồm **2 lớp độc lập**, kết hợp như AdGuard Pro:

```
┌─────────────────────────────────────────────────────┐
│                   Main App (Container)                │
│  ┌─────────────────┐        ┌──────────────────────┐ │
│  │  YouTube Module  │        │   Settings / Stats   │ │
│  │  (WKWebView)     │        │   Blocklist Manager  │ │
│  └─────────────────┘        └──────────────────────┘ │
└───────────────┬───────────────────────┬──────────────┘
                │ App Group (shared)     │
                ▼                        ▼
┌─────────────────────────────┐  ┌──────────────────────┐
│  Network Extension Target    │  │  Shared Container     │
│  (DNS Proxy / Packet Tunnel) │  │  blocklist, settings  │
│  → chặn ads cho mọi app      │  │  (UserDefaults suite) │
└─────────────────────────────┘  └──────────────────────┘
```

- **Main App:** giao diện chính + module YouTube.
- **Network Extension:** target riêng, chạy nền, lọc DNS (lớp chặn ads mạng).
- **App Group:** chia sẻ blocklist + cấu hình giữa app và extension.

---

## 2. Lớp 1 — YouTube WebView Module (Phase 1)

### 2.1 Thành phần
- `WKWebView` load `https://m.youtube.com`.
- `WKContentRuleList` — chặn request domain ads ngay trong webview.
- `WKUserScript` — inject JS xóa DOM ads + tự skip video ad.
- `AVAudioSession` — phát nền.
- PiP qua `WKWebView.allowsPictureInPictureMediaPlayback`.

### 2.2 Cấu hình WebView (tham chiếu)

```swift
import WebKit
import AVFoundation

func makeYouTubeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    // JS chặn/skip ads — cần cập nhật khi YouTube đổi DOM
    let adBlockJS = """
    (function () {
      setInterval(function () {
        document.querySelectorAll(
          '.ytp-ad-module, ytd-ad-slot-renderer, .video-ads, ytm-promoted-video-renderer'
        ).forEach(function (e) { e.remove(); });
        var skip = document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button');
        if (skip) skip.click();
        var v = document.querySelector('video');
        if (v && document.querySelector('.ad-showing')) { v.currentTime = v.duration; }
      }, 500);
    })();
    """
    let script = WKUserScript(source: adBlockJS,
                              injectionTime: .atDocumentEnd,
                              forMainFrameOnly: false)
    config.userContentController.addUserScript(script)

    return WKWebView(frame: .zero, configuration: config)
}

// Background audio + Lock screen
func enableBackgroundAudio() {
    try? AVAudioSession.sharedInstance()
        .setCategory(.playback, mode: .moviePlayback)
    try? AVAudioSession.sharedInstance().setActive(true)
}
```

### 2.3 Info.plist
```
UIBackgroundModes = [ audio, fetch ]
```
Bật Capability: **Background Modes → Audio, AirPlay, and Picture in Picture**.

---

## 3. Lớp 2 — DNS Ad Filtering (Phase 2)

### 3.1 Lựa chọn Extension

| Loại | Ưu | Nhược | Đề xuất |
|---|---|---|---|
| **NEDNSProxyProvider** | Nhẹ, đúng mục đích lọc DNS | Chỉ lọc DNS | ✅ Ưu tiên |
| **NEPacketTunnelProvider** | Lọc cả IP/SNI | Phức tạp, tốn pin | Phương án 2 |
| **NEDNSSettingsManager** (DoH/DoT) | Đơn giản, dùng DNS server có sẵn (NextDNS) | Lọc ở server, ít kiểm soát local | Phương án nhanh |

### 3.2 Luồng lọc DNS

```
App A ──DNS query "ads.doubleclick.net"──► NEDNSProxyProvider
                                                  │
                          tra blocklist (App Group)
                                                  │
                    ┌─────────────┴─────────────┐
              trong blocklist            không trong list
                    │                           │
            trả NXDOMAIN (chặn)        forward tới DNS thật (1.1.1.1)
```

### 3.3 Entitlements bắt buộc
- `com.apple.developer.networking.networkextension` (cần Apple cấp, khai báo lý do).
- `com.apple.security.application-groups` (chia sẻ dữ liệu).

---

## 4. Shared Data (App Group)

| Dữ liệu | Định dạng | Ghi/Đọc bởi |
|---|---|---|
| Blocklist domain | file/SQLite trong shared container | Main app ghi, Extension đọc |
| Cấu hình bật/tắt | UserDefaults(suiteName:) | Cả hai |
| Thống kê chặn | UserDefaults / file | Extension ghi, app đọc |

---

## 5. Cấu trúc target (Xcode)

```
view-youtube-ios.xcodeproj
├── App                 (main app)
│   ├── YouTube/        F2,F3,F4
│   ├── Settings/       F6
│   └── Blocklist/      F5
├── DNSFilterExtension  (Network Extension target — F1)
└── Shared              (App Group: models, blocklist store)
```

---

## 6. UI Framework (đã chốt)

**SwiftUI cho toàn bộ UI** + **UIKit interop** cho phần cần kiểm soát thấp:
- `WKWebView` bọc bằng `UIViewRepresentable`.
- PiP qua `AVPictureInPictureController` (cần delegate UIKit).
- Now Playing / Lock Screen qua `MPRemoteCommandCenter` + `MPNowPlayingInfoCenter`.

```swift
import SwiftUI
import WebKit

struct YouTubeWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeYouTubeWebView() } // §2.2
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
    }
}
```

→ Giao diện đẹp (SwiftUI declarative + animation sẵn), code gọn, vẫn kiểm soát được WebView/PiP.

## 7. DNS — Phương án theo SideStore (đã chốt: dùng cả 2, fallback PA C)

| PA | Module | Entitlement | Dùng khi |
|----|--------|-------------|----------|
| **A** | `NEDNSProxyProvider` + `NEPacketTunnelProvider` (§3) | NetworkExtension (restricted) | Có dev account trả phí |
| **C** | App sinh & cài **.mobileconfig** trỏ DoH (NextDNS/AdGuard DNS) | KHÔNG cần | SideStore free cert |

> Xem PRD §4.4. Free cert → PA A không ký được. Code Phase 2 nên tách interface `AdFilterService` để swap A ↔ C không ảnh hưởng UI.

```swift
protocol AdFilterService {
    func enable() async throws
    func disable() async throws
    var isActive: Bool { get }
}
// NetworkExtensionFilter: AdFilterService  (PA A)
// DNSProfileFilter:      AdFilterService  (PA C — cài .mobileconfig)
```

## 8. CI/CD — GitHub Actions → IPA cho SideStore

```
.github/workflows/build.yml
  runs-on: macos-latest
  steps:
    - checkout
    - xcodebuild archive (unsigned hoặc ký dev)
    - export IPA (không cần App Store provisioning)
    - upload artifact / release  →  cài qua SideStore
```

- Build **unsigned IPA** hoặc ký bằng cert dev; SideStore tự ký lại bằng Apple ID người dùng khi cài.
- Phát hành dưới dạng GitHub Release để SideStore (qua source URL) bắt được bản mới.

## 9. Blocklist source (đề xuất)
- EasyList, AdGuard DNS Filter (PA C dùng DoH server đã có sẵn blocklist của NextDNS/AdGuard).

## 10. F1 — DNS qua .mobileconfig (PA C, chốt)

```
App ──sinh .mobileconfig (DNSSettings = DoH, server = NextDNS profile)──► người dùng cài
        │
iOS toàn hệ thống ──DNS query──► NextDNS DoH (https://dns.nextdns.io/<profileID>)
                                      │
                          NextDNS chặn theo blocklist + denylist người dùng
```

- Profile dùng key `com.apple.dnsSettings.managed`, `DNSProtocol = HTTPS`, `ServerURL = https://dns.nextdns.io/<profileID>`.
- App chỉ **sinh file + mở để cài** (Settings → Profile Downloaded). Không cần entitlement.

## 11. F7 — Quản lý domain qua NextDNS API (mô hình review-sau)

> Quan trọng: app KHÔNG bắt được DNS query thời gian thực (không có local interceptor ở PA C). Dữ liệu domain lấy từ **NextDNS API** (có độ trễ, không phải push tức thì).

```swift
protocol DomainManagerService {
    func fetchRecentDomains() async throws -> [DomainLogEntry]   // GET /profiles/:id/logs
    func allow(_ domain: String) async throws                    // PATCH allowlist
    func block(_ domain: String) async throws                    // PATCH denylist
    func markForLater(_ domain: String)                          // local, App Group
}

struct DomainLogEntry: Identifiable {
    let id: String
    let domain: String
    let timestamp: Date
    let status: Status   // allowed / blocked / default
    enum Decision { case allow, block, later, none }
    var decision: Decision = .none
}
```

NextDNS REST API (cần API key người dùng):
| Mục đích | Endpoint (tham khảo) |
|---|---|
| Lấy log domain đã truy cập | `GET /profiles/{id}/logs` |
| Thêm allowlist | `POST/PATCH /profiles/{id}/allowlist` |
| Thêm denylist | `POST/PATCH /profiles/{id}/denylist` |

> [Unverified] Đường dẫn endpoint trên là theo cấu trúc NextDNS API thường dùng — cần kiểm chứng lại với tài liệu NextDNS hiện hành khi implement.

## 12. F8 — Domain Inspector (option xem sau)

```swift
protocol DomainInspector {
    func category(of domain: String) async -> String?   // NextDNS category
    func whois(_ domain: String) async -> WhoisInfo?     // tổ chức sở hữu, ngày tạo
}
```
- Dùng cho domain ở trạng thái "Để sau" → giúp quyết Allow/Block.
- Nguồn: NextDNS category trong log + dịch vụ WHOIS công khai.
