# Checklist demo và nộp Flutter Map Lab

## Question 1 · Vị trí

- [ ] Ảnh map nền tải thành công.
- [ ] Ảnh cấp quyền và marker tại tọa độ thiết bị.
- [ ] Ghi latitude, longitude, accuracy và nguồn dữ liệu.
- [ ] Demo từ chối quyền hoặc tắt GPS, sau đó chọn pin/tìm địa chỉ để phục hồi.
- [ ] Nếu dùng AVD, chú thích rõ “GPS mô phỏng/dữ liệu thử”.

## Question 2 · Tuyến

- [ ] Ảnh hai điểm đầu cuối và đường `LineString` trên map.
- [ ] Ảnh cùng màn hình có số km, số phút và giờ đến dự kiến.
- [ ] Đổi một điểm và chứng minh tuyến/số đo thay đổi.
- [ ] Demo lỗi không có tuyến hoặc mất mạng; không hiển thị số liệu giả.
- [ ] Khi so sánh app khác, ghi cả tọa độ đầu cuối, phương tiện và nguồn ETA.

## Question 3 · GPS foreground

- [ ] Ảnh/video bấm **Theo dõi GPS thời gian thực**.
- [ ] Video có nhiều fix với timestamp/sai số thay đổi.
- [ ] Ghi rõ dùng điện thoại thật hay route thử trong AVD Extended Controls.
- [ ] Tắt theo dõi và chứng minh marker không nhận sự kiện mới.
- [ ] Đưa app về background rồi mở lại; subscription chỉ resume khi chế độ theo dõi còn bật.
- [ ] Chọn pin thủ công và chứng minh GPS live không ghi đè pin.

## Thông tin nộp

- Source nền: `codex/web-location-search-fix@8651d5a`.
- Flutter/Dart: ghi kết quả `flutter --version`.
- Thiết bị: ghi model điện thoại hoặc tên AVD/API level.
- Ngày demo: ____________________.
- Người thực hiện/MSSV: ____________________.
- Link ảnh/video: ____________________.

## Giải thích bắt buộc

- MapLibre chỉ render; OSRM mới trả khoảng cách/thời gian tuyến ô tô.
- GeoJSON/OSRM dùng `longitude,latitude`, còn `GeoPoint` trong app lưu `latitude,longitude`.
- Haversine là đường chim bay, không thay thế quãng đường OSRM.
- `distance` là mét; `duration` là giây; demo đổi sang kilomet/phút.
- ETA chưa có live traffic và có thể khác ứng dụng thương mại.
- `distanceFilter = 10 m` không bảo đảm một sự kiện mỗi 10 giây.
