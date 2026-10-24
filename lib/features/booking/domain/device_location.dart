import 'ride_models.dart';

class DeviceLocation {
  const DeviceLocation(
    this.point, {
    required this.accuracyMeters,
    this.sourceLabel,
    this.timestamp,
    this.isMocked = false,
  });
  final GeoPoint point;
  final double accuracyMeters;
  final String? sourceLabel;
  final DateTime? timestamp;
  final bool isMocked;
}

abstract class DeviceLocationService {
  Future<DeviceLocation> currentLocation();
}

enum LocationFailureKind { permission, serviceDisabled, timeout, unavailable }

class LocationFailure implements Exception {
  const LocationFailure(this.kind, this.message);
  final LocationFailureKind kind;
  final String message;
  @override
  String toString() => message;
}
