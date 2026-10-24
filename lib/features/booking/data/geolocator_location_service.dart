import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_location.dart';
import '../domain/ride_models.dart';
import 'location_platform.dart';
import 'location_source_provider.dart';

class GeolocatorLocationService implements DeviceLocationService {
  GeolocatorLocationService({
    GeolocatorPlatform? platform,
    bool? web,
    this.deadline = const Duration(seconds: 20),
  }) : _platform = platform ?? createLocationPlatform(),
       _web = web ?? kIsWeb;

  final GeolocatorPlatform _platform;
  final bool _web;
  final Duration deadline;

  LocationFailure get _permissionFailure => LocationFailure(
    LocationFailureKind.permission,
    _web
        ? 'Trang chưa có quyền vị trí. Cho phép Vị trí trong quyền của trang, rồi thử lại.'
        : 'Ứng dụng chưa có quyền vị trí. Cho phép Vị trí trong cài đặt ứng dụng, rồi thử lại.',
  );

  @override
  Future<DeviceLocation> currentLocation() async {
    try {
      // Includes permission waits: the browser's own timeout excludes time spent
      // waiting for a permission prompt, so it cannot bound the whole operation.
      return await _readLocation().timeout(deadline);
    } on LocationFailure {
      rethrow;
    } on PermissionDeniedException {
      throw _permissionFailure;
    } on LocationServiceDisabledException {
      throw const LocationFailure(
        LocationFailureKind.serviceDisabled,
        'Dịch vụ vị trí đang tắt. Bật Vị trí trên thiết bị, rồi thử lại.',
      );
    } on TimeoutException {
      if (_web) {
        final permission = await _browserPermission();
        if (permission == LocationPermission.deniedForever) {
          throw _permissionFailure;
        }
        if (permission == LocationPermission.denied) {
          throw const LocationFailure(
            LocationFailureKind.timeout,
            'Trình duyệt chưa xác nhận quyền Vị trí cho trang này. Cho phép Vị trí trong quyền của trang rồi bấm Thử lại. Bạn cũng có thể tìm địa chỉ hoặc chọn điểm đón trên bản đồ.',
          );
        }
      }
      throw const LocationFailure(
        LocationFailureKind.timeout,
        'Nguồn định vị chưa trả về tọa độ. Kiểm tra dịch vụ Vị trí của thiết bị rồi thử lại, hoặc tìm địa chỉ/chọn điểm đón trên bản đồ.',
      );
    } catch (_) {
      if (_platform is LocationSourceProvider &&
          (_platform as LocationSourceProvider).sourceLabel.startsWith(
            'Windows',
          )) {
        throw const LocationFailure(
          LocationFailureKind.unavailable,
          'Windows chưa cung cấp vị trí mới. Kiểm tra dịch vụ Vị trí và quyền vị trí của ứng dụng desktop trong Cài đặt Windows, rồi thử lại.',
        );
      }
      throw LocationFailure(
        LocationFailureKind.unavailable,
        _web
            ? 'Trình duyệt chưa cung cấp được vị trí. Kiểm tra Vị trí của thiết bị và quyền trang; mở bằng Chrome/Edge qua localhost hoặc HTTPS nếu cần.'
            : 'Thiết bị chưa cung cấp được vị trí. Kiểm tra GPS và kết nối mạng, hoặc chọn điểm đón trên bản đồ.',
      );
    }
  }

  Future<LocationPermission?> _browserPermission() async {
    try {
      return await _platform.checkPermission().timeout(
        const Duration(milliseconds: 300),
      );
    } catch (_) {
      // Some browsers do not implement the Permissions API.
      return null;
    }
  }

  Future<DeviceLocation> _readLocation() async {
    if (_web &&
        await _browserPermission() == LocationPermission.deniedForever) {
      throw _permissionFailure;
    }
    if (!_web) {
      if (!await _platform.isLocationServiceEnabled()) {
        throw const LocationFailure(
          LocationFailureKind.serviceDisabled,
          'Dịch vụ vị trí đang tắt. Bật Vị trí trên thiết bị, rồi thử lại.',
        );
      }
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw _permissionFailure;
      }
    }
    // The browser watch requests permission as part of the location operation;
    // never start a second position request just to request permission.
    // First cancels the web watch after a fix or stream error. A Dart stream
    // deadline also clears the watch if the browser never supplies a position.
    // This avoids relying on geolocator_web 4.1.4's browser timeout conversion.
    final position = _web
        ? await _platform
              .getPositionStream(
                locationSettings: WebSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 12),
                  maximumAge: Duration.zero,
                ),
              )
              .timeout(deadline)
              .first
        : await _platform.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw const FormatException('Invalid location coordinates');
    }
    return DeviceLocation(
      GeoPoint(position.latitude, position.longitude),
      accuracyMeters: position.accuracy,
      sourceLabel: _platform is LocationSourceProvider
          ? (_platform as LocationSourceProvider).sourceLabel
          : null,
    );
  }
}
