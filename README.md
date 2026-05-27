# ViewTube

App iOS: xem YouTube **không quảng cáo** + **Picture-in-Picture** + **nghe khi khóa màn hình**, kèm **chặn ads ở tầng DNS** (NextDNS) và **quản lý domain thủ công** (Allow / Block / Để sau).

> Phân phối qua **GitHub Actions → SideStore** (không App Store). Tài liệu chi tiết: [docs/](docs/).

## Tính năng

| | Mô tả | Trạng thái |
|---|---|---|
| YouTube không ads | WebView `m.youtube.com` + chặn request ads + xóa/skip DOM ads | ✅ MVP |
| Picture-in-Picture | Video nổi khi rời app | ✅ |
| Nghe nền / khóa màn hình | `AVAudioSession` + điều khiển Lock Screen | ✅ |
| Chặn ads DNS (mọi app) | `.mobileconfig` → NextDNS DoH (PA C) | ✅ |
| Quản lý domain (F7) | Xem log NextDNS → Allow / Block / Để sau | ✅ |
| Tra cứu domain (F8) | WHOIS / category | ⏳ kế hoạch |

## Build (local, cần macOS + Xcode)

```bash
brew install xcodegen
xcodegen generate          # sinh ViewTube.xcodeproj từ project.yml
open ViewTube.xcodeproj     # build & run trên simulator/thiết bị
```

> Project được sinh từ `project.yml` (XcodeGen). KHÔNG commit `.xcodeproj` — sửa cấu hình trong `project.yml`.

## CI → IPA cho SideStore

- Push lên `main` hoặc tạo tag `v*` → GitHub Actions build **unsigned IPA** (`.github/workflows/build.yml`).
- Lấy IPA ở tab **Actions → Artifacts**, hoặc ở **Release** nếu push tag.
- SideStore tự ký lại bằng Apple ID của bạn khi cài.

### Cài qua SideStore — cách 1: file IPA
1. Tải `ViewTube.ipa` từ Artifact/Release.
2. SideStore → **+** → chọn file IPA → cài.

### Cài qua SideStore — cách 2: Source (tự cập nhật) ⭐
1. Trong SideStore → **Sources** → **+** → dán URL source:
   ```
   https://raw.githubusercontent.com/xuanha31/view-youtube-ios/main/apps.json
   ```
2. Mở ViewTube trong source → **Install**.
3. Mỗi lần bạn push tag `v*`, CI build IPA mới + tự cập nhật `apps.json` → SideStore báo có bản mới.

> (Khuyến nghị) Bật **auto-refresh** trong SideStore — free cert hết hạn **7 ngày**.

## Cấu hình NextDNS (cho chặn ads DNS + quản lý domain)

1. Đăng ký miễn phí tại [nextdns.io](https://nextdns.io).
2. Lấy **Profile ID** (Setup) + **API key** (Account).
3. App → **Settings** → nhập Profile ID + API key → **Lưu**.
4. **Settings → Cài DNS profile** → cài `.mobileconfig` (Settings → Profile Downloaded).
5. Tab **Domains** → xem domain đã truy cập → Allow / Block / Để sau.

## Cấu trúc

```
project.yml                  # XcodeGen — nguồn sự thật của project
App/
├── ViewTubeApp.swift        # @main
├── ContentView.swift        # TabView: YouTube / Domains / Settings
├── YouTube/                 # Phase 1: WebView + AdBlocker + PiP + audio
├── DNS/                     # Phase 2: .mobileconfig generator (PA C)
├── Domains/                 # F7: NextDNS client + quản lý domain
├── Settings/
└── Shared/                  # App Group + Keychain
.github/workflows/build.yml  # CI build unsigned IPA
```

## Giới hạn (đọc kỹ — xem [docs/01-project-overview-prd.md](docs/01-project-overview-prd.md))

- ❌ **Không** chặn ads trong app YouTube chính thức — chỉ trong tab YouTube của app này.
- ❌ DNS **không** chặn được ads cùng domain nội dung (Facebook/TikTok/YouTube native).
- ❌ Quản lý domain **không** real-time — mô hình xem-log-rồi-quyết (NextDNS có độ trễ).
- ⚠️ JS chặn ads YouTube cần cập nhật khi YouTube đổi giao diện (`App/YouTube/AdBlocker.swift`).
- ⚠️ Vi phạm ToS YouTube — dùng cho mục đích cá nhân.
