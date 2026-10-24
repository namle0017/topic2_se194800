import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Tracks device positions only while the app's map screen is in foreground.
class ForegroundTracker extends ChangeNotifier {
  ForegroundTracker({GeolocatorPlatform? platform, DateTime Function()? now})
    : _platform = platform ?? GeolocatorPlatform.instance,
      _now = now ?? DateTime.now;

  final GeolocatorPlatform _platform;
  final DateTime Function() _now;

  StreamSubscription<Position>? _subscription;
  bool _disposed = false;
  int _generation = 0;

  Position? latest;
  String? error;
  bool isTracking = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    isTracking = false;
    await previous?.cancel();
    if (_disposed || generation != _generation) return;

    try {
      if (!await _platform.isLocationServiceEnabled()) {
        throw StateError('Hãy bật dịch vụ vị trí của thiết bị.');
      }

      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Ứng dụng chưa có quyền vị trí.');
      }
      if (_disposed || generation != _generation) return;

      error = null;
      latest = null;
      _subscription = _platform
          .getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          )
          .listen(
            (position) => _onPosition(position, generation),
            onError: (Object _) => _onError(generation),
          );
      isTracking = true;
      _emit();
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = switch (failure) {
        StateError() => failure.message,
        _ => 'Không thể bắt đầu theo dõi vị trí. Thử lại.',
      };
      isTracking = false;
      _emit();
    }
  }

  void _onPosition(Position position, int generation) {
    if (_disposed || generation != _generation) return;
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      return;
    }

    final age = _now().difference(position.timestamp);
    if (age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5)) {
      return;
    }

    latest = position;
    error = null;
    _emit();
  }

  void _onError(int generation) {
    if (_disposed || generation != _generation) return;
    error = 'Không nhận được cập nhật vị trí. Thử lại.';
    _emit();
  }

  Future<void> stop() async {
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    isTracking = false;
    await subscription?.cancel();
    _emit();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
