import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  List<double> get coordinates => [longitude, latitude];
  String get cacheKey =>
      '${latitude.toStringAsFixed(7)},${longitude.toStringAsFixed(7)}';

  double distanceTo(GeoPoint other) {
    const radians = math.pi / 180;
    final a =
        math.pow(math.sin((other.latitude - latitude) * radians / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin((other.longitude - longitude) * radians / 2), 2);
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    this.countryCode,
  });
  final String id;
  final String name;
  final String address;
  final GeoPoint point;
  final String? countryCode;
}

class TripRoute {
  TripRoute({
    required List<GeoPoint> points,
    required this.distanceMeters,
    required this.durationSeconds,
  }) : points = List.unmodifiable(points) {
    if (points.length < 2 ||
        !distanceMeters.isFinite ||
        distanceMeters <= 0 ||
        !durationSeconds.isFinite ||
        durationSeconds <= 0 ||
        points.any(
          (p) =>
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        )) {
      throw const FormatException('Invalid driving route');
    }
    _cumulative = [0];
    for (var i = 1; i < points.length; i++) {
      _cumulative.add(_cumulative.last + points[i - 1].distanceTo(points[i]));
    }
  }
  final List<GeoPoint> points;
  late final List<double> _cumulative;
  final double distanceMeters;
  final double durationSeconds;
  double get kilometers => distanceMeters / 1000;
  int get minutes => (durationSeconds / 60).ceil();

  factory TripRoute.fromOsrm(Map<String, dynamic> json) {
    final coordinates =
        (json['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    return TripRoute(
      points: coordinates
          .map(
            (p) => GeoPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList(),
      distanceMeters: (json['distance'] as num).toDouble(),
      durationSeconds: (json['duration'] as num).toDouble(),
    );
  }

  /// Interpolate by road length so the demo car does not jump across long segments.
  GeoPoint pointAt(double progress) {
    final target = _cumulative.last * progress.clamp(0, 1);
    if (target <= 0) return points.first;
    if (target >= _cumulative.last) return points.last;
    var low = 1, high = points.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_cumulative[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final i = low - 1;
    final length = _cumulative[low] - _cumulative[i];
    final fraction = length == 0 ? 0.0 : (target - _cumulative[i]) / length;
    return GeoPoint(
      points[i].latitude +
          (points[low].latitude - points[i].latitude) * fraction,
      points[i].longitude +
          (points[low].longitude - points[i].longitude) * fraction,
    );
  }
}

/// Fixed reference tariff: Green SM HCMC published distance tiers, read 06/10/2026.
/// This educational policy is applied nationwide; it is not a live operator quote.
enum RideType {
  standard('Tiêu chuẩn', 'Chuyến đi hằng ngày', 4, 30500, 15200, 14700, 13300),
  comfort('Comfort', 'Rộng rãi, thoải mái hơn', 4, 34400, 16500, 16000, 14400),
  xl('Xe lớn', 'Thêm chỗ cho cả nhóm', 6, 39500, 18900, 18400, 16500);

  const RideType(
    this.label,
    this.description,
    this.seats,
    this.baseFare,
    this.firstTier,
    this.secondTier,
    this.lastTier,
  );
  final String label, description;
  final int seats, baseFare, firstTier, secondTier, lastTier;

  FareBreakdown breakdown(TripRoute route) {
    final km = route.kilometers;
    final firstKm = (km - 2).clamp(0.0, 10.0);
    final secondKm = (km - 12).clamp(0.0, 13.0);
    final lastKm = math.max(0.0, km - 25);
    return FareBreakdown([
      FareLine('Mở cửa · 2 km đầu', baseFare.toDouble()),
      if (firstKm > 0)
        FareLine(
          '${firstKm.toStringAsFixed(2)} km × ${formatVnd(firstTier)}/km',
          firstKm * firstTier,
        ),
      if (secondKm > 0)
        FareLine(
          '${secondKm.toStringAsFixed(2)} km × ${formatVnd(secondTier)}/km',
          secondKm * secondTier,
        ),
      if (lastKm > 0)
        FareLine(
          '${lastKm.toStringAsFixed(2)} km × ${formatVnd(lastTier)}/km',
          lastKm * lastTier,
        ),
    ]);
  }

  int fareFor(TripRoute route) => breakdown(route).total;
}

class FareLine {
  const FareLine(this.label, this.amount);
  final String label;
  final double amount;
}

class FareBreakdown {
  FareBreakdown(this.lines);
  final List<FareLine> lines;
  double get subtotal => lines.fold(0, (sum, l) => sum + l.amount.round());
  int get total => (subtotal / 1000).ceil() * 1000;
  double get rounding => total - subtotal;
}

String formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60, rest = minutes % 60;
  return '$hours giờ${rest == 0 ? '' : ' $rest phút'}';
}

String formatArrival(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return '${formatTime(time)}${sameDay ? '' : ' · ${time.day}/${time.month}'}';
}

String formatVnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
String formatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

abstract class BookingRepository {
  Future<List<Place>> search(String query, GeoPoint? near);
  Future<Place> reverse(GeoPoint point);
  Future<TripRoute> route(Place pickup, Place destination);
  void dispose();
}

/// Optional fast, cancellable autocomplete capability.
abstract interface class LivePlaceSearch {
  List<Place> cachedSuggestions(String query, GeoPoint? near);
  void cancelSearch();
}

class MapServiceException implements Exception {
  const MapServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
