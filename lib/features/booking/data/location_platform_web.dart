import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:geolocator/geolocator.dart';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;

import 'browser_position_options.dart';
import 'location_source_provider.dart';

GeolocatorPlatform createLocationPlatform() => _BrowserLocationPlatform();

/// Project-owned browser adapter: geolocator_web 4.1.4 passes microseconds to
/// the browser's millisecond timeout. Keep the native plugin unchanged.
class _BrowserLocationPlatform extends GeolocatorPlatform
    implements LocationSourceProvider {
  bool get useDeviceCompanion =>
      const bool.fromEnvironment('LOCAL_DEVICE_LOCATION') &&
      Uri.base.host == '127.0.0.1';
  @override
  String sourceLabel = 'Trình duyệt';
  @override
  Future<LocationPermission> checkPermission() async {
    if (useDeviceCompanion) {
      sourceLabel = 'Windows Location';
      // This explicitly enabled local preview uses Windows' own location
      // permission. A browser-site permission does not describe that provider.
      // GetGeopositionAsync checks OS access; no browser permission is changed.
      return LocationPermission.unableToDetermine;
    }
    final status = await web.window.navigator.permissions
        .query({'name': 'geolocation'}.jsify()! as JSObject)
        .toDart;
    return switch (status.state) {
      'granted' => LocationPermission.whileInUse,
      'denied' => LocationPermission.deniedForever,
      _ => LocationPermission.denied,
    };
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    int? watchId;
    var cancelled = false;
    final abort = Completer<void>();
    final options = BrowserPositionOptions(
      timeout: locationSettings?.timeLimit ?? const Duration(seconds: 12),
    );
    late final StreamController<Position> controller;
    controller = StreamController<Position>(
      onListen: () {
        if (useDeviceCompanion) {
          unawaited(() async {
            final client = http.Client();
            try {
              final request = http.AbortableRequest(
                'POST',
                Uri.base.resolve('/__ride/location'),
                abortTrigger: abort.future,
              );
              request.headers['X-Ride-Location'] = '1';
              final response = await client
                  .send(request)
                  .then(http.Response.fromStream);
              if (cancelled) return;
              if (response.statusCode != 200) {
                throw StateError('Companion unavailable');
              }
              final json = jsonDecode(response.body) as Map<String, dynamic>;
              final timestamp = DateTime.parse(json['timestamp'] as String);
              if (DateTime.now().difference(timestamp).abs() >
                  const Duration(seconds: 30)) {
                throw StateError('Stale device fix');
              }
              final accuracy = (json['accuracy'] as num).toDouble();
              if (!accuracy.isFinite || accuracy <= 0) {
                throw StateError('Invalid accuracy');
              }
              sourceLabel = json['source'] as String;
              controller.add(
                Position(
                  latitude: (json['latitude'] as num).toDouble(),
                  longitude: (json['longitude'] as num).toDouble(),
                  timestamp: timestamp,
                  accuracy: accuracy,
                  altitude: 0,
                  altitudeAccuracy: 0,
                  heading: 0,
                  headingAccuracy: 0,
                  speed: 0,
                  speedAccuracy: 0,
                ),
              );
            } catch (_) {
              if (!cancelled) {
                controller.addError(
                  const PositionUpdateException('Windows location unavailable'),
                );
              }
            } finally {
              client.close();
            }
          }());
          return;
        }
        try {
          if (!web.window.isSecureContext) {
            throw const PositionUpdateException('Secure context required');
          }
          watchId = web.window.navigator.geolocation.watchPosition(
            (web.GeolocationPosition position) {
              if (cancelled) return;
              final coords = position.coords;
              sourceLabel = 'Trình duyệt';
              controller.add(
                Position(
                  latitude: coords.latitude,
                  longitude: coords.longitude,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    position.timestamp,
                  ),
                  accuracy: coords.accuracy,
                  altitude: coords.altitude ?? 0,
                  altitudeAccuracy: coords.altitudeAccuracy ?? 0,
                  heading: coords.heading ?? 0,
                  headingAccuracy: 0,
                  speed: coords.speed ?? 0,
                  speedAccuracy: 0,
                ),
              );
            }.toJS,
            (web.GeolocationPositionError error) {
              if (cancelled) return;
              controller.addError(switch (error.code) {
                1 => PermissionDeniedException(error.message),
                3 => TimeoutException(error.message),
                _ => PositionUpdateException(error.message),
              });
            }.toJS,
            web.PositionOptions(
              enableHighAccuracy: true,
              timeout: options.timeoutMilliseconds,
              maximumAge: options.maximumAgeMilliseconds,
            ),
          );
        } catch (error, stack) {
          controller.addError(error, stack);
        }
      },
      onCancel: () {
        cancelled = true;
        if (!abort.isCompleted) abort.complete();
        final id = watchId;
        if (id != null) web.window.navigator.geolocation.clearWatch(id);
      },
    );
    return controller.stream;
  }
}
