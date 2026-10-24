import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_lab/features/map/foreground_tracker.dart';

final _now = DateTime(2026, 10, 19, 15);

Position _position({
  double latitude = 10.7767,
  double longitude = 106.7009,
  DateTime? timestamp,
  double accuracy = 8,
  bool isMocked = false,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp ?? _now,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
  isMocked: isMocked,
);

class TrackerPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int streamRequests = 0;
  int streamCancellations = 0;
  LocationSettings? settings;
  final List<StreamController<Position>> streams = [];

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamRequests++;
    settings = locationSettings;
    late StreamController<Position> controller;
    controller = StreamController<Position>(
      onCancel: () {
        streamCancellations++;
        return controller.close();
      },
    );
    streams.add(controller);
    return controller.stream;
  }
}

void main() {
  test('publishes valid foreground fixes with the 10 metre filter', () async {
    final platform = TrackerPlatform();
    final tracker = ForegroundTracker(platform: platform, now: () => _now);

    await tracker.start();
    platform.streams.single.add(_position(accuracy: 6, isMocked: true));
    await Future<void>.delayed(Duration.zero);

    expect(tracker.isTracking, isTrue);
    expect(tracker.latest?.latitude, 10.7767);
    expect(tracker.latest?.accuracy, 6);
    expect(tracker.latest?.isMocked, isTrue);
    expect(platform.settings?.accuracy, LocationAccuracy.high);
    expect(platform.settings?.distanceFilter, 10);

    tracker.dispose();
  });

  test(
    'does not subscribe when service or permission is unavailable',
    () async {
      final disabledPlatform = TrackerPlatform()..serviceEnabled = false;
      final disabled = ForegroundTracker(
        platform: disabledPlatform,
        now: () => _now,
      );
      await disabled.start();
      expect(disabled.isTracking, isFalse);
      expect(disabled.error, contains('dịch vụ vị trí'));
      expect(disabledPlatform.streamRequests, 0);

      final deniedPlatform = TrackerPlatform()
        ..permission = LocationPermission.denied
        ..requestedPermission = LocationPermission.deniedForever;
      final denied = ForegroundTracker(
        platform: deniedPlatform,
        now: () => _now,
      );
      await denied.start();
      expect(denied.isTracking, isFalse);
      expect(denied.error, contains('quyền vị trí'));
      expect(deniedPlatform.streamRequests, 0);

      disabled.dispose();
      denied.dispose();
    },
  );

  test(
    'ignores stale future and invalid fixes but reports stream errors',
    () async {
      final platform = TrackerPlatform();
      final tracker = ForegroundTracker(platform: platform, now: () => _now);
      await tracker.start();
      final stream = platform.streams.single;

      stream.add(
        _position(timestamp: _now.subtract(const Duration(seconds: 31))),
      );
      stream.add(_position(timestamp: _now.add(const Duration(seconds: 6))));
      stream.add(_position(latitude: double.nan));
      stream.add(_position(longitude: 181));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.latest, isNull);

      stream.add(
        _position(timestamp: _now.subtract(const Duration(seconds: 30))),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tracker.latest, isNotNull);

      stream.addError(StateError('provider stopped'));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.error, contains('Không nhận được cập nhật vị trí'));

      tracker.dispose();
    },
  );

  test('restart stop and dispose cancel every active subscription', () async {
    final platform = TrackerPlatform();
    final tracker = ForegroundTracker(platform: platform, now: () => _now);

    await tracker.start();
    await tracker.start();
    expect(platform.streamRequests, 2);
    expect(platform.streamCancellations, 1);

    await tracker.stop();
    expect(tracker.isTracking, isFalse);
    expect(platform.streamCancellations, 2);

    await tracker.start();
    tracker.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(platform.streamCancellations, 3);
  });
}
