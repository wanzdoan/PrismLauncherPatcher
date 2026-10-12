# Prism Launcher Universal Offline Patcher ⚡

> **Công cụ mở khóa chơi Offline (Non-premium / Cracked) cho Prism Launcher trên Windows.**  
> Tương thích với **mọi phiên bản Prism Launcher** mà không cần tài khoản Microsoft bản quyền.

---

## 🚀 1 Lệnh Setup Chạy Nhanh (Quick Run)

Chỉ cần sao chép và dán lệnh bên dưới vào **CMD** hoặc **PowerShell** (hoặc nhấn `Win + R`):

### 🔹 Cách 1: Menu Tương Tác (Khuyên dùng)
Hiển thị menu trực quan để bạn chọn: Patch, Thêm tài khoản, Khôi phục bản gốc, hoặc Mở Launcher.

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/wanzdoan/PrismLauncherPatcher/main/patch.ps1 | iex"
```

*(Nếu bạn đang mở sẵn cửa sổ PowerShell, chỉ cần gõ rút gọn:)*
```powershell
irm https://raw.githubusercontent.com/wanzdoan/PrismLauncherPatcher/main/patch.ps1 | iex
```

---

### 🔹 Cách 2: Tự Động Patch Luôn (1-Click Auto Patch)
Tự động tìm kiếm Prism Launcher và patch ngay lập tức trong 0.1 giây:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/wanzdoan/PrismLauncherPatcher/main/install.ps1 | iex"
```

---

## 🛠️ Tùy Chọn Dòng Lệnh (CLI Parameters)

Nếu bạn tải script `patch.ps1` về máy, bạn có thể chạy trực tiếp các tham số sau:

```powershell
# Xem trạng thái file prismlauncher.exe
.\patch.ps1 -Status

# Tiến hành patch Prism Launcher
.\patch.ps1 -Patch

# Thêm tài khoản Offline và đặt làm mặc định
.\patch.ps1 -AddAccount "TenNhanVatCuaBan"

# Xem danh sách tài khoản hiện có
.\patch.ps1 -ListAccounts

# Khôi phục file gốc ban đầu (nếu cần)
.\patch.ps1 -Unpatch
```

---

## ✨ Điểm Nổi Bật

- **Dynamic Xref Discovery**: Tự động phân tích cấu trúc nhị phân PE x64 tại runtime. Không dùng offset cố định nên tương thích với mọi phiên bản Prism Launcher hiện tại và tương lai.
- **Tự động sao lưu an toàn**: Luôn tự động tạo bản sao lưu `prismlauncher.exe.bak` trước khi chỉnh sửa.
- **Chuẩn UUID v3**: Tích hợp thuật toán tạo UUID Minecraft offline chuẩn RFC 4122 (MD5 namespace `OfflinePlayer:`).
- **Không yêu cầu cài thêm phần mềm**: Hoạt động ngay trên PowerShell có sẵn của Windows.
