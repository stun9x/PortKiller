# Hướng dẫn phát triển và phát hành

## Môi trường

1. Cài Xcode hoặc Swift toolchain có hỗ trợ macOS 13.
2. Clone repository.
3. Kiểm tra toolchain:

```bash
swift --version
```

## Vòng lặp phát triển

```bash
swift build
swift run
```

Sau khi thay đổi UI hoặc scanner, kiểm tra tối thiểu:

- App khởi động được và icon xuất hiện trên menu bar.
- Tab Ports có dữ liệu khi máy có process listen.
- Tab Processes hiển thị CPU/memory hợp lý.
- Tìm kiếm không phân biệt hoa thường.
- SIGTERM cập nhật danh sách; SIGKILL chỉ dùng khi cần.
- App không crash khi `lsof`/`ps` trả output bất thường.

## Build bundle local

```bash
./build.sh
open PortKiller.app
```

`build.sh` tạo app bundle tối thiểu, đặt `LSUIElement=true` và ad-hoc sign. Đây chưa phải quy trình phân phối ngoài máy phát triển.

## Checklist trước commit

- `swift build` chạy thành công.
- `./build.sh` tạo được app bundle.
- Không commit `.build/`, `.DS_Store` hoặc `PortKiller.app`.
- Cập nhật README/docs nếu thay đổi hành vi, yêu cầu hệ thống hoặc thao tác người dùng.
- Không thêm lệnh shell có thể xóa dữ liệu người dùng.

## Phát hành công khai

Bản phát hành production nên bổ sung:

- Apple Developer signing identity.
- Hardened Runtime và notarization.
- Versioning nhất quán trong `Info.plist`.
- Release notes và checksum cho artefact.
- CI build trên runner macOS sạch.
