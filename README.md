# PRM393 · Flutter Map Lab

Bài thực hành hoàn chỉnh ba yêu cầu trong `Map_Practice_Huong_dan_thuc_hanh`:

1. Hiển thị MapLibre/OpenFreeMap, xin quyền và lấy vị trí thiết bị; khi GPS lỗi có thể tìm địa chỉ hoặc chọn pin.
2. Tìm hai điểm bằng Photon, gọi OSRM theo thứ tự `longitude,latitude`, vẽ `LineString` và hiển thị km, phút, giờ đến dự kiến.
3. Theo dõi GPS foreground trên Android/iOS, hiển thị nguồn/sai số/thời gian, dừng đúng lifecycle và giới hạn việc tính lại tuyến.

Source nền được đối chiếu từ branch `codex/web-location-search-fix`, commit `8651d5a`. Phần theo dõi foreground được bổ sung trong project `map_lab` này.

## Công nghệ và kiến trúc

| Thành phần | Vai trò |
|---|---|
| Flutter/Dart | UI, state và logic ứng dụng |
| MapLibre GL | Render bản đồ, marker, camera và tuyến |
| OpenFreeMap | Style, tiles, sprites và fonts của bản đồ nền |
| Geolocator | Vị trí hiện tại và stream vị trí foreground |
| Photon | Tìm địa điểm và reverse geocoding |
| OSRM | Tuyến ô tô, khoảng cách, thời gian và GeoJSON geometry |

`lib/features/booking/domain` chứa model thuần Dart; `data` chứa GPS/HTTP/search; `presentation` chứa controller, màn hình và map. `lib/features/map/foreground_tracker.dart` chỉ chịu trách nhiệm subscription GPS foreground và lọc fix không hợp lệ.

## Cài đặt

Yêu cầu Flutter 3.47.x, Dart 3.13.x và JDK 21 cho Android.

```powershell
flutter --version
flutter doctor -v
flutter pub get
```

Android đã khai báo `INTERNET`, `ACCESS_COARSE_LOCATION` và `ACCESS_FINE_LOCATION`. iOS đã có `NSLocationWhenInUseUsageDescription`.

## Chạy Android

1. Bật Location Services trên điện thoại/AVD.
2. Chọn device trong Android Studio hoặc kiểm tra bằng `flutter devices`.
3. Chạy:

```powershell
flutter run -d <device-id>
```

Hoặc build APK debug bằng JDK 21:

```powershell
.\tool\build_android.ps1
```

APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`.

## Chạy web

Trên Windows, script preview build web và lấy vị trí từ Windows Location:

```powershell
.\tool\run_web.ps1
```

Mở `http://127.0.0.1:52341/`. Nếu dùng `flutter run -d chrome`, vị trí đến từ Browser Geolocation và trang phải chạy trên localhost hoặc HTTPS.

Theo dõi GPS liên tục của Question 3 chỉ bật trên native Android/iOS. Web vẫn hỗ trợ lấy một vị trí mới mỗi lần nhấn và chọn pin thủ công.

## Thực hiện ba câu hỏi

### Question 1 · Map và vị trí thiết bị

- Khi mở app, map dùng khung nhìn Việt Nam cho tới khi nhận được tọa độ thật.
- Nút vị trí gọi Geolocator với độ chính xác cao và deadline; UI hiển thị marker cùng `accuracy` do thiết bị báo.
- Reverse geocoding chỉ bổ sung tên gần đó, không thay tọa độ pin/GPS.
- Khi quyền bị từ chối, dịch vụ tắt hoặc timeout, app kết thúc loading và cho thử lại, tìm địa chỉ hoặc chọn pin.

### Question 2 · Khoảng cách và thời gian

- Photon trả các địa điểm trong Việt Nam; người dùng cũng có thể kéo map để chọn pin.
- OSRM nhận `longitude,latitude;longitude,latitude` với profile `driving`.
- `distance` từ response là mét; UI chia `1000` để hiện kilomet.
- `duration` là giây; UI chia `60`, làm tròn lên để hiện phút.
- Geometry của đúng response đó được chuyển thành `GeoPoint(latitude, longitude)` và vẽ thành `LineString`.
- ETA là thời gian OSRM cộng vào thời điểm hiện tại. Demo **không có dữ liệu kẹt xe trực tiếp**, nên không cam kết giống ứng dụng thương mại.

### Question 3 · Theo dõi vị trí foreground

- Bấm **Theo dõi GPS thời gian thực** trên màn hình chính Android/iOS.
- Tracker dùng `LocationAccuracy.high` và `distanceFilter = 10 m`. Đây là ngưỡng di chuyển, không phải chu kỳ 10 giây.
- Fix cũ hơn 30 giây, quá 5 giây trong tương lai, không hữu hạn hoặc ngoài phạm vi vĩ/kinh độ bị bỏ qua.
- UI hiển thị `GPS thiết bị` hoặc `GPS mô phỏng`, sai số và thời điểm nhận.
- Pin thủ công không bị GPS ghi đè. Khi điểm đón đang là `device-location`, marker và camera có thể bám vị trí mới.
- Nếu đã có điểm đến, tuyến chỉ được yêu cầu lại sau khi di chuyển ít nhất 50 m **và** cách request live trước ít nhất 10 giây.
- Subscription dừng khi người dùng tắt theo dõi, app `inactive/hidden/paused/detached`, rời màn hình hoặc controller bị dispose. Khi app `resumed`, tracker chỉ chạy lại nếu người dùng vẫn để chế độ theo dõi bật.

## Kiểm thử

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Test bao phủ quyền/timeout, giữ tọa độ GPS chính xác, pin thủ công, thứ tự lat/lon, OSRM geometry/distance/duration, response cũ, tracker start/stop/dispose, fix cũ/sai, metadata GPS mô phỏng và giới hạn 50 m + 10 giây.

## Demo và bằng chứng nộp bài

Xem [docs/LAB_CHECKLIST.md](docs/LAB_CHECKLIST.md). Tọa độ gửi từ Android Emulator Extended Controls phải ghi là **dữ liệu thử/GPS mô phỏng**. Chỉ điện thoại thật mới phù hợp để mô tả là vị trí thực tế; `accuracy` nhỏ trên AVD không thay đổi điều đó.

Các provider công cộng không có SLA. Khi Photon/OSRM mất mạng hoặc không tìm thấy đường ô tô gần pin, app hiển thị lỗi và không bịa địa chỉ, tuyến, khoảng cách hoặc thời gian.
