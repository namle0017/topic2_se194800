import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/ride_models.dart';
import 'place_search.dart';

/// One instance owns the HTTP client, caches and the routing request queue.
class LiveBookingRepository implements BookingRepository, LivePlaceSearch {
  LiveBookingRepository({http.Client? client, Uri? searchEndpoint})
    : _client = client ?? http.Client(),
      _searchEndpoint =
          searchEndpoint ??
          Uri.base.resolve(
            const String.fromEnvironment(
              'PHOTON_SEARCH_URL',
              defaultValue: 'https://photon.komoot.io/api/',
            ),
          );
  final http.Client _client;
  final Uri _searchEndpoint;
  final _searchCache = <String, List<Place>>{};
  final _routeCache = <String, TripRoute>{};
  final _reverseCache = <String, Place>{};
  Future<void> _routeQueue = Future.value();
  DateTime? _lastRouteRequest;
  final _knownPlaces = <String, Place>{};
  Completer<void>? _searchAbort;
  bool _disposed = false;
  Map<String, String> get _headers => kIsWeb
      ? {}
      : {'User-Agent': 'PRM393-RideMapDemo/1.0 (educational project)'};

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      if (response.body.contains('NoSegment')) {
        throw const MapServiceException(
          'Điểm đã chọn không gần đường ô tô. Di chuyển pin đến lối vào hoặc đường gần đó.',
        );
      }
      throw const MapServiceException(
        'Dịch vụ bản đồ đang bận. Anh thử lại nhé.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<List<Place>> search(String query, GeoPoint? near) async {
    if (query.trim().length < 2) return [];
    cancelSearch();
    final key = '${normalizeQuery(query)}:${near?.cacheKey}';
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    final abort = Completer<void>();
    _searchAbort = abort;
    try {
      final request = http.AbortableRequest(
        'GET',
        _searchEndpoint.replace(
          queryParameters: {
            'q': query.trim(),
            'limit': '8',
            'bbox': '102.14,8.17,110.0,23.4',
            'countrycode': 'VN',
          },
        ),
        abortTrigger: abort.future,
      );
      request.headers.addAll(_headers);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Place search');
            },
          );
      if (response.statusCode != 200) {
        throw const FormatException('Place search');
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final result = (json['features'] as List)
          .map((f) => _photonPlace(f as Map<String, dynamic>))
          .where((p) => p.countryCode == 'VN')
          .toList();
      if (!_disposed && !abort.isCompleted) {
        _searchCache[key] = result;
        for (final p in result) {
          _knownPlaces[p.id] = p;
        }
        while (_knownPlaces.length > 100) {
          _knownPlaces.remove(_knownPlaces.keys.first);
        }
        if (_searchCache.length > 60) {
          _searchCache.remove(_searchCache.keys.first);
        }
      }
      return result;
    } on http.RequestAbortedException {
      return [];
    } catch (_) {
      throw const MapServiceException(
        'Tìm kiếm đang chậm. Thử lại hoặc chọn vị trí trên bản đồ.',
      );
    } finally {
      if (identical(_searchAbort, abort)) _searchAbort = null;
    }
  }

  @override
  List<Place> cachedSuggestions(String query, GeoPoint? near) =>
      matchingPlaces(_knownPlaces.values, query, near);

  @override
  void cancelSearch() {
    final abort = _searchAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _searchAbort = null;
  }

  Place _photonPlace(Map<String, dynamic> feature, {GeoPoint? exactPoint}) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final coords =
        (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    final street = [
      properties['housenumber'],
      properties['street'],
    ].where((v) => v != null).join(' ');
    final address = [
      if (street.isNotEmpty) street,
      properties['district'],
      properties['city'],
      properties['county'],
      properties['state'],
      properties['country'],
    ].where((v) => v != null && v.toString().isNotEmpty).toSet().join(', ');
    return Place(
      id: 'photon-${properties['osm_type']}-${properties['osm_id']}',
      name: (properties['name'] ?? properties['street'] ?? 'Điểm trên bản đồ')
          .toString(),
      address: address,
      countryCode: properties['countrycode']?.toString().toUpperCase(),
      point:
          exactPoint ??
          GeoPoint(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
    );
  }

  @override
  Future<Place> reverse(GeoPoint point) async {
    if (_reverseCache.containsKey(point.cacheKey)) {
      return _reverseCache[point.cacheKey]!;
    }
    // Preserve the actual pin/GPS coordinate, not the geocoder's POI centroid.
    try {
      final json = await _get(
        Uri.https('photon.komoot.io', '/reverse', {
          'lat': '${point.latitude}',
          'lon': '${point.longitude}',
          'limit': '1',
        }),
      );
      final features = json['features'] as List;
      if (features.isNotEmpty) {
        final place = _photonPlace(
          features.first as Map<String, dynamic>,
          exactPoint: point,
        );
        if (!_disposed) _reverseCache[point.cacheKey] = place;
        return place;
      }
    } catch (_) {
      /* Coordinates remain usable when reverse geocoding is unavailable. */
    }
    return Place(
      id: 'pin-${point.cacheKey}',
      name: 'Điểm đã chọn',
      address:
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      point: point,
    );
  }

  @override
  Future<TripRoute> route(Place pickup, Place destination) async {
    for (final place in [pickup, destination]) {
      final p = place.point;
      if ((place.countryCode != null && place.countryCode != 'VN') ||
          !p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude < 8.17 ||
          p.latitude > 23.4 ||
          p.longitude < 102.14 ||
          p.longitude > 110) {
        throw const MapServiceException(
          'Demo hỗ trợ điểm đón và điểm đến tại Việt Nam. Chọn lại địa điểm.',
        );
      }
    }
    if (pickup.point.distanceTo(destination.point) < 30) {
      throw const MapServiceException(
        'Điểm đến quá gần điểm đón. Chọn một địa điểm khác.',
      );
    }
    final key = '${pickup.point.cacheKey}|${destination.point.cacheKey}';
    if (_routeCache.containsKey(key)) return _routeCache[key]!;
    // OSRM's public demo permits at most one request per second, including retries.
    final previous = _routeQueue;
    final done = Completer<void>();
    _routeQueue = done.future;
    await previous;
    try {
      if (_disposed) throw const MapServiceException('Ứng dụng đã đóng.');
      if (_lastRouteRequest != null) {
        final wait =
            1100 - DateTime.now().difference(_lastRouteRequest!).inMilliseconds;
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      }
      _lastRouteRequest = DateTime.now();
      final coords =
          '${pickup.point.longitude},${pickup.point.latitude};${destination.point.longitude},${destination.point.latitude}';
      final json = await _get(
        Uri.https('router.project-osrm.org', '/route/v1/driving/$coords', {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
          'alternatives': 'false',
          'radiuses': '200;200',
        }),
      );
      final routes = json['routes'] as List?;
      if (json['code'] != 'Ok' || routes == null || routes.isEmpty) {
        throw const MapServiceException(
          'Không có tuyến ô tô giữa hai điểm này.',
        );
      }
      final route = TripRoute.fromOsrm(routes.first as Map<String, dynamic>);
      if (!_disposed) _routeCache[key] = route;
      return route;
    } on MapServiceException {
      rethrow;
    } catch (_) {
      throw const MapServiceException(
        'Chưa tải được tuyến đường. Kiểm tra mạng và thử lại.',
      );
    } finally {
      done.complete();
    }
  }

  @override
  void dispose() {
    cancelSearch();
    _disposed = true;
    _client.close();
  }
}
