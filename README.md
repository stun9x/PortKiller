# PortKiller

[VI](README.md) | [EN](README.en.md)

Ứng dụng macOS chạy trên menu bar để theo dõi port đang mở và quản lý các tiến trình đang chạy.

PortKiller giúp bạn:

- Liệt kê TCP port đang `LISTEN` và các UDP endpoint.
- Xem command, PID, user và địa chỉ bind của từng port.
- Theo dõi tiến trình cùng CPU và memory hiện tại.
- Quét các thư mục `node_modules` trong thư mục home và sắp xếp theo kích thước giảm dần.
- Tìm kiếm theo tên, port hoặc PID.
- Gửi `SIGTERM` để dừng mềm hoặc `SIGKILL` để buộc dừng tiến trình.

> **Cảnh báo:** Dừng nhầm tiến trình có thể làm mất dữ liệu hoặc khiến ứng dụng/hệ thống hoạt động không ổn định. Hãy kiểm tra PID và command trước khi kill.

## Yêu cầu

- macOS 13 Ventura trở lên.
- Swift 5.9 trở lên; dự án hiện build được với Swift 6.x.
- Quyền truy cập các binary hệ thống `/usr/sbin/lsof` và `/bin/ps`.

## Cài đặt và chạy

### Build app bundle

```bash
./build.sh
open PortKiller.app
```

Script build release bằng Swift Package Manager, đóng gói thành `PortKiller.app` và ad-hoc code sign để chạy local.

### Chạy trực tiếp từ SwiftPM

```bash
swift run
```

Khi chạy, biểu tượng PortKiller xuất hiện trên menu bar. Nhấn biểu tượng để mở cửa sổ quản lý.

## Cách sử dụng

### Ports

Tab **Ports** refresh tự động mỗi 3 giây. Mỗi dòng hiển thị port, command, protocol, địa chỉ bind, PID và user.

- Nhấn nút đỏ để gửi `SIGTERM`.
- Mở menu của nút và chọn **Force Kill (SIGKILL)** khi tiến trình không chịu dừng.
- Dùng ô tìm kiếm để lọc theo command, port hoặc PID.

### Processes

Tab **Processes** hiển thị các tiến trình được sắp xếp theo CPU giảm dần, cùng user, CPU và memory. Có thể tìm theo tên hoặc PID và thực hiện cùng thao tác kill.

### Node Modules

Tab **Node Modules** quét các thư mục `node_modules` bên dưới thư mục home, tính kích thước đệ quy và sắp xếp từ lớn đến bé. Mỗi dòng hiển thị kích thước, số package trực tiếp và đường dẫn. Có thể tìm kiếm theo đường dẫn và refresh thủ công.

## Kiến trúc

Mã nguồn hiện nằm trong một executable target duy nhất:

```text
Sources/PortKiller/PortKillerApp.swift
├── Models       PortInfo, ProcInfo
├── Shell helper run(...)
├── Scanning     scanPorts(), scanProcesses()
├── Monitor      polling, kill và trạng thái UI
├── UI           ContentView, KillMenu
└── App          PortKillerApp / MenuBarExtra
```

Chi tiết luồng dữ liệu và giới hạn hiện tại nằm trong [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Cấu trúc repository

```text
.
├── Package.swift
├── Sources/PortKiller/PortKillerApp.swift
├── build.sh
├── README.md
└── docs/
    ├── ARCHITECTURE.md
    └── DEVELOPMENT.md
```

## Phát triển

```bash
swift build
swift test       # hiện chưa có test target; lệnh được ghi nhận cho CI tương lai
./build.sh
```

Quy trình đóng góp, kiểm tra trước commit và phát hành được ghi trong [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Giấy phép

Dự án được phát hành theo [MIT License](LICENSE).
