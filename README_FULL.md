# Prism Launcher Universal Offline Patcher ⚡

> **Công cụ patch đa năng cho Prism Launcher trên Windows:** Cho phép thêm và chơi game bằng tài khoản Offline (Cracked / Non-premium) ngay lập tức mà **không cần** phải đăng nhập tài khoản Microsoft bản quyền trước. Tương thích với **mọi phiên bản** Prism Launcher.

---

## 📖 Mục lục (Table of Contents)
1. [Giới thiệu & Vấn đề giải quyết](#-giới-thiệu--vấn-đề-giải-quyết)
2. [Các phiên bản công cụ](#-các-phiên-bản-công-cụ)
3. [Hướng dẫn sử dụng nhanh](#-hướng-dẫn-sử-dụng-nhanh)
   - [Cách 1: Sử dụng Standalone GUI (`PrismOfflinePatcher.exe`)](#cách-1-sử-dụng-giao-diện-đồ-họa-prismofflinepatcherexe)
   - [Cách 2: Sử dụng PowerShell Script (`patch.ps1`)](#cách-2-sử-dụng-powershell-script-patchps1)
   - [Cách 3: Sử dụng Python (`prism_patcher.py`)](#cách-3-sử-dụng-python-prism_patcherpy)
   - [Cách 4: Sử dụng Standalone CLI (`PrismOfflinePatcher-cli.exe`)](#cách-4-sử-dụng-cli-prismofflinepatcher-cliexe)
4. [Cơ chế kỹ thuật (Technical Breakdown)](#-cơ-chế-kỹ-thuật-technical-breakdown)
   - [Tại sao Prism Launcher chặn tài khoản Offline?](#tại-sao-prism-launcher-chặn-tài-khoản-offline)
   - [Tại sao công cụ này tương thích với mọi phiên bản?](#tại-sao-công-cụ-này-tương-thích-với-mọi-phiên-bản)
   - [Chi tiết mã máy (Byte Patch)](#chi-tiết-mã-máy-byte-patch)
5. [Tính năng quản lý tài khoản (Account Manager)](#-tính-năng-quản-lý-tài-khoản-account-manager)
6. [Câu hỏi thường gặp (FAQ)](#-câu-hỏi-thường-gặp-faq)

---

## 🎯 Giới thiệu & Vấn đề giải quyết

Theo mặc định trong Prism Launcher chính thức:
1. Nút **"Add Offline"** bị vô hiệu hóa (`disabled`) và hiển thị thông báo lỗi:
   > *"You must add a Microsoft account that owns Minecraft before you can add an offline account"*
2. Khi khởi chạy game, `LaunchController` kiểm tra xem tài khoản có sở hữu Minecraft (`ownsMinecraft`) hay không. Nếu chỉ có tài khoản Offline, launcher sẽ:
   - Ép buộc chuyển chế độ khởi chạy sang **Demo Mode** (`LaunchMode::Demo`).
   - Yêu cầu người chơi mua bản quyền game để chơi bản đầy đủ (*"purchase the game first to play the full version"*).
   - Hoặc cố gắng gửi request refresh token lên server Microsoft và báo lỗi khi thất bại.

**Prism Launcher Universal Offline Patcher** giải quyết triệt để vấn đề này bằng cách can thiệp trực tiếp vào file nhị phân PE (`prismlauncher.exe`) đã cài đặt trên máy. Người chơi có thể tạo tài khoản Offline và nhấn "Launch" vào game ngay mà không cần bất kỳ tài khoản Microsoft nào.

---

## 📦 Các phiên bản công cụ

Dự án cung cấp đầy đủ 4 cách sử dụng tùy theo sở thích của người dùng:

| Tên file | Định dạng | Yêu cầu | Mô tả |
| :--- | :--- | :--- | :--- |
| **`PrismOfflinePatcher.exe`** | WinForms GUI | Windows 7/8/10/11 (Không cần cài thêm gì) | Giao diện đồ họa Dark Theme hiện đại, thao tác 1-click chuột, tích hợp quản lý tài khoản. |
| **`patch.ps1`** | PowerShell Script | Windows PowerShell 5.1+ | Chạy trực tiếp trên terminal PowerShell, hỗ trợ cả menu tương tác và cờ lệnh (`-Patch`, `-Status`, `-AddAccount`). |
| **`PrismOfflinePatcher-cli.exe`** | Console CLI | Windows 7/8/10/11 | Bản CLI siêu nhẹ, chạy cực nhanh (< 0.1s), thích hợp cho script tự động hóa. |
| **`prism_patcher.py`** | Python Script | Python 3.8+ | Bản mã nguồn Python hoàn chỉnh kèm cả GUI (Tkinter) và CLI. |

---

## 🚀 Hướng dẫn sử dụng nhanh

### Cách 1: Sử dụng giao diện đồ họa (`PrismOfflinePatcher.exe`)

1. Đóng Prism Launcher nếu đang mở.
2. Nhấp đúp chuột vào file **`PrismOfflinePatcher.exe`**.
3. Công cụ sẽ tự động nhận diện đường dẫn cài đặt Prism Launcher và trạng thái hiện tại.
4. Nhấn nút **`⚡ Patch Prism Launcher`**.
5. Nhập tên nhân vật mong muốn vào ô **Tên nhân vật** và nhấn **`+ Thêm Offline Account`**.
6. Nhấn nút **`▶ Mở Prism Launcher`** để vào game ngay!

*(Muốn quay về bản gốc ban đầu: chỉ cần bấm **`↺ Khôi phục gốc`**)*.

---

### Cách 2: Sử dụng PowerShell Script (`patch.ps1`)

Mở terminal PowerShell tại thư mục dự án và chạy:

```powershell
# Xem trạng thái hiện tại
.\patch.ps1 -Status

# Tiến hành patch Prism Launcher
.\patch.ps1 -Patch

# Thêm tài khoản offline và đặt làm mặc định
.\patch.ps1 -AddAccount "TenNhanVatCuaBan"

# Xem danh sách tài khoản đã cấu hình
.\patch.ps1 -ListAccounts

# Khôi phục lại bản gốc nếu cần
.\patch.ps1 -Unpatch
```

Nếu chạy không kèm tham số `.\patch.ps1`, script sẽ hiển thị menu tương tác số 1-6 cực kỳ tiện lợi.

---

### Cách 3: Sử dụng Python (`prism_patcher.py`)

Nếu máy bạn đã cài sẵn Python:

```bash
# Mở giao diện đồ họa Tkinter
python prism_patcher.py --gui

# Hoặc dùng dòng lệnh
python prism_patcher.py --status
python prism_patcher.py --patch
python prism_patcher.py --add-account "Player1"
python prism_patcher.py --unpatch
```

---

### Cách 4: Sử dụng CLI (`PrismOfflinePatcher-cli.exe`)

```cmd
# Kiểm tra trạng thái
PrismOfflinePatcher-cli.exe --status

# Patch Prism Launcher
PrismOfflinePatcher-cli.exe --patch

# Thêm tài khoản offline
PrismOfflinePatcher-cli.exe --add-account "Steve"

# Khôi phục file gốc
PrismOfflinePatcher-cli.exe --unpatch
```

---

## 🔬 Cơ chế kỹ thuật (Technical Breakdown)

### Tại sao Prism Launcher chặn tài khoản Offline?

Trong mã nguồn Prism Launcher C++:
1. `AccountList::anyAccountIsValid()` duyệt danh sách tài khoản và kiểm tra `ownsMinecraft()`:
   ```cpp
   // MinecraftAccount.h
   bool ownsMinecraft() const {
       return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;
   }
   ```
   Do tài khoản Offline có `type == AccountType::Offline`, hàm luôn trả về `false`.
2. Hàm `AccountListPage::on_actionAddOffline_triggered()` kiểm tra:
   ```cpp
   if (!m_accounts->anyAccountIsValid()) {
       CustomMessageBox::selectable(this, tr("Error"),
           tr("You must add a Microsoft account that owns Minecraft before you can add an offline account.")
       )->show();
       return;
   }
   ```
3. Trong `LaunchController::decideLaunchMode()`:
   Nếu tài khoản chưa được Microsoft chứng thực quyền sở hữu, launcher ép chuyển sang `LaunchMode::Demo` và gọi `askPlayDemo()`.

### Tại sao công cụ này tương thích với mọi phiên bản?

Hầu hết các patcher trên mạng đều dùng kỹ thuật **hardcoded byte offset** (địa chỉ cố định trong file). Khi Prism Launcher ra mắt phiên bản mới (ví dụ từ 9.x lên 10.x, 11.x, v.v.), cấu trúc file nhị phân thay đổi, khiến patcher bị hỏng hoặc làm crash launcher.

Công cụ này sử dụng **Dynamic Structural Cross-Reference Discovery (Phân tích xref cấu trúc động)**:
```
[Chuỗi thông báo lỗi trong .rdata]
      │
      ▼ (Tìm RIP-relative displacement)
[Vị trí tham chiếu trong .text]
      │
      ▼ (Truy ngược opcode CALL 0xE8)
[Target 1: AccountList::anyAccountIsValid entry point]
```

1. **Target 1 (`AccountList::anyAccountIsValid`)**:
   - Quét tìm chuỗi `"You must add a Microsoft account that owns Minecraft"`.
   - Tính toán RVA trong `.rdata` và tìm lệnh tham chiếu đến địa chỉ này trong `.text`.
   - Từ lệnh tham chiếu, quét ngược tìm lệnh `call` (opcode `0xE8`) ngay trước đó. Hàm được gọi chính là `AccountList::anyAccountIsValid`.
2. **Target 2 (`LaunchController::decideLaunchMode`)**:
   - Quét tìm chuỗi `"This account does not own Minecraft"`.
   - Tìm hàm chứa thông báo này (`askPlayDemo`) và tìm các hàm gọi đến nó (`LaunchController::login`).
   - Phân tích call graph trong `login()` để định vị chính xác `decideLaunchMode()`.
   - Đọc trực tiếp các byte displacement của lệnh máy trong prologue để tự động trích xuất offset của hai trường `m_wantedLaunchMode` và `m_actualLaunchMode` trong struct `LaunchController` (thường là `0xA8` và `0xAC`).

Nhờ thuật toán này, **dù Prism Launcher có cập nhật lên phiên bản 12.x, 13.x hay biên dịch lại với compiler khác, patcher vẫn tự động tìm thấy chính xác vị trí cần can thiệp!**

---

### Chi tiết mã máy (Byte Patch)

#### 1. `AccountList::anyAccountIsValid` (3 bytes)
Hàm gốc thực hiện vòng lặp phức tạp để kiểm tra tài khoản. Patcher thay thế đầu hàm bằng:
```assembly
mov al, 1    ; B0 01  -> Trả về true (1)
ret          ; C3     -> Trả về ngay lập tức
```
*Kết quả:* Nút "Add Offline" trong giao diện Prism Launcher luôn được bật, và mọi bước kiểm tra tài khoản hợp lệ đều vượt qua thành công.

#### 2. `LaunchController::decideLaunchMode` (18 bytes)
Hàm gốc thực hiện kiểm tra DRM và ép chuyển sang chế độ Demo. Patcher thay thế bằng:
```assembly
mov eax, [rcx + wanted_offset]   ; 8B 81 A8 00 00 00  -> Lấy chế độ người dùng mong muốn (Normal / Offline)
mov [rcx + actual_offset], eax   ; 89 81 AC 00 00 00  -> Đặt làm chế độ khởi chạy thực tế
mov eax, 1                       ; B8 01 00 00 00     -> Return LaunchModeDecision::Continue
ret                              ; C3
```
*Kết quả:* Game khởi chạy ngay lập tức với tài khoản offline, không kết nối server xác thực của Microsoft, không bật pop-up lỗi, không bị chuyển sang Demo Mode.

---

## 👤 Tính năng quản lý tài khoản (Account Manager)

Công cụ tích hợp bộ sinh UUID Minecraft tiêu chuẩn (UUID Version 3 / RFC 4122):
- Minecraft Offline UUID được tạo từ hash MD5 chuỗi: `OfflinePlayer:<Username>`
- Đặt `Version = 3` (`hash[6] = (hash[6] & 0x0F) | 0x30`)
- Đặt `Variant = 1` (`hash[8] = (hash[8] & 0x3F) | 0x80`)

Tệp `%APPDATA%\PrismLauncher\accounts.json` được ghi định dạng chuẩn với đầy đủ `entitlement` (`ownsMinecraft: true`, `canPlayMinecraft: true`) và `ygg` token, đảm bảo đồng bộ hoàn toàn với dữ liệu của Prism Launcher.

Ngoài ra, sau khi patch, bạn hoàn toàn có thể vào menu **"Manage Accounts" -> "Add Offline"** của chính Prism Launcher để thêm bao nhiêu tài khoản tùy thích!

---

## ❓ Câu hỏi thường gặp (FAQ)

#### Q: Có cần chạy lại tool khi cập nhật Prism Launcher không?
**A:** Có. Khi bạn cập nhật Prism Launcher qua trình cập nhật tự động, file `prismlauncher.exe` mới sẽ được tải về đè lên file cũ. Bạn chỉ cần mở lại `PrismOfflinePatcher.exe` hoặc chạy `.\patch.ps1 -Patch`, công cụ sẽ phân tích phiên bản mới và patch lại chỉ trong vài giây.

#### Q: Làm sao để cài Skin/Cape khi chơi tài khoản Offline?
**A:** Vì không sử dụng server xác thực Mojang, game sẽ dùng skin mặc định của Steve/Alex. Bạn có thể cài đặt mod **CustomSkinLoader** (hoặc skin system của Ely.by / SkinRestorer trên server) để hiển thị skin và cape đẹp mắt.

#### Q: Chơi Online trên các server có được không?
**A:** Có. Bạn có thể vào chơi bình thường trên tất cả các server Minecraft mở chế độ `online-mode=false` (server Cracked / Offline) như Herobrine, PikaNetwork, Jartex, server Aternos, server cá nhân của bạn bè, v.v. Các server bản quyền ép buộc xác thực Microsoft (`online-mode=true`) sẽ yêu cầu tài khoản Microsoft chính thức.

#### Q: File gốc có bị mất không?
**A:** Không. Trước khi patch bất kỳ byte nào, công cụ luôn tự động tạo một bản sao lưu an toàn tại `prismlauncher.exe.bak`. Bạn có thể khôi phục lại bất kỳ lúc nào chỉ với một nút bấm.
