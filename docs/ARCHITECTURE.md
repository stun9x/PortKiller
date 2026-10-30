# Kiến trúc PortKiller

[VI](ARCHITECTURE.md) | [EN](ARCHITECTURE.en.md)

## Tổng quan

PortKiller là một macOS menu-bar utility viết bằng SwiftUI. Ứng dụng không có cửa sổ chính độc lập và đặt activation policy là `accessory`, vì vậy không hiện icon trên Dock.

Luồng chính:

```text
MenuBarExtra
    ↓
ContentView
    ↓
Monitor (@MainActor, ObservableObject)
    ├── scanPorts()      → /usr/sbin/lsof
    ├── scanProcesses()  → /bin/ps
    └── kill(...)         → Darwin.kill(SIGTERM | SIGKILL)
```

## Models

`PortInfo` đại diện cho một network endpoint với PID, command, user, protocol, address và port.

`ProcInfo` đại diện cho một process với PID, tên, user, CPU percentage và memory theo MB.

`NodeModulesInfo` đại diện cho một thư mục `node_modules`, gồm đường dẫn, kích thước đệ quy theo byte và số package trực tiếp.

`CacheInfo` đại diện cho một cache được biết trước của npm, Yarn, pnpm, Corepack hoặc Chrome. App chỉ quét các đường dẫn cố định này và sắp xếp theo kích thước giảm dần.

Hai model conform `Identifiable` và `Hashable` để dùng trực tiếp trong SwiftUI `ForEach`.

## Quét port

`scanPorts()` thực hiện hai lệnh:

```text
lsof -nP -iTCP -sTCP:LISTEN
lsof -nP -iUDP
```

Kết quả được tách theo dòng, lấy command/PID/user và parse cột `NAME` để lấy địa chỉ cùng port. Endpoint trùng nhau được loại bằng `Set`, sau đó sắp xếp theo port tăng dần.

Các kết nối TCP đã established có dạng `a->b` và được bỏ qua. Với UDP, output của `lsof` có thể khác nhau giữa phiên bản macOS; parser bỏ qua dòng không đủ trường hoặc không parse được port.

## Quét process

`scanProcesses()` dùng:

```text
ps -axo pid=,pcpu=,rss=,user=,comm=
```

RSS được đổi từ KB sang MB. Tên process được rút gọn về component cuối của path và kết quả được sắp xếp theo CPU giảm dần.

## Đồng bộ và refresh

`Monitor` là `@MainActor` để mọi thay đổi `@Published` an toàn với SwiftUI. Việc gọi binary hệ thống chạy trong `Task.detached` nhằm tránh block UI. Timer refresh mỗi 3 giây; thao tác kill refresh lại sau 0,6 giây để UI kịp phản ánh process đã kết thúc.

Quét `node_modules` chỉ chạy khi người dùng mở tab tương ứng hoặc bấm refresh. Root mặc định là thư mục home; các thư mục con được tính kích thước đệ quy và sắp xếp giảm dần.

Nút xoá yêu cầu xác nhận và chỉ chấp nhận thư mục có tên chính xác là `node_modules`, nằm bên dưới home directory và không phải symbolic link.

Tab **Caches** cũng yêu cầu xác nhận trước khi xoá và chỉ chấp nhận các đường dẫn nằm trong danh sách cache cố định của app.

## Kill process

- Click chính: gửi `SIGTERM`, cho process cơ hội shutdown đúng cách.
- Menu phụ **Force Kill**: gửi `SIGKILL`, không cho process cleanup.

Ứng dụng không dùng `sudo` và không tự nâng quyền. Nếu process thuộc user khác hoặc bị hệ thống bảo vệ, `kill` có thể thất bại; lỗi từ `errno` được hiển thị trong status bar.

## Giới hạn và hướng mở rộng

- Chưa có test target hoặc fixture cho output `lsof`/`ps`.
- Parser phụ thuộc format CLI của macOS.
- Chưa có quyền Accessibility, launch-at-login, icon asset hay notarization.
- `run(...)` hiện trả về chuỗi rỗng khi command lỗi; abstraction trả cả exit code/stderr sẽ giúp chẩn đoán tốt hơn.
- Có thể tách scanner, process-killer và view model thành các file/module riêng khi tính năng tăng.
