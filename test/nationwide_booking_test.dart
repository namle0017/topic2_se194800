import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_lab/core/app_theme.dart';
import 'package:map_lab/features/booking/data/live_booking_repository.dart';
import 'package:map_lab/features/booking/data/place_search.dart';
import 'package:map_lab/features/booking/domain/device_location.dart';
import 'package:map_lab/features/booking/domain/ride_models.dart';
import 'package:map_lab/features/booking/presentation/booking_controller.dart';
import 'package:map_lab/features/booking/presentation/booking_screen.dart';

const south = Place(
  id: 'south',
  name: 'Điểm phía Nam',
  address: '',
  point: GeoPoint(10.8, 106.7),
  countryCode: 'VN',
);
const north = Place(
  id: 'north',
  name: 'Điểm phía Bắc',
  address: '',
  point: GeoPoint(21.03, 105.85),
  countryCode: 'VN',
);

class LocationStub implements DeviceLocationService {
  GeoPoint point = south.point;
  bool denied = false;
  Completer<DeviceLocation>? pending;
  int calls = 0;
  @override
  Future<DeviceLocation> currentLocation() async {
    calls++;
    if (denied) {
      throw const LocationFailure(
        LocationFailureKind.permission,
        'Thiếu quyền vị trí',
      );
    }
    return pending?.future ?? DeviceLocation(point, accuracyMeters: 124);
  }
}

class RepositoryStub implements BookingRepository, LivePlaceSearch {
  double meters = 4407.2, seconds = 392.4;
  int routes = 0, cancellations = 0;
  final queries = <String>[];
  List<Place> known = [];
  @override
  Future<Place> reverse(GeoPoint p) async => Place(
    id: p.cacheKey,
    name: 'Địa chỉ từ thiết bị',
    address: '',
    point: p,
    countryCode: 'VN',
  );
  @override
  Future<TripRoute> route(Place a, Place b) async {
    routes++;
    return TripRoute(
      points: [a.point, b.point],
      distanceMeters: meters,
      durationSeconds: seconds,
    );
  }

  @override
  Future<List<Place>> search(String q, GeoPoint? p) async {
    queries.add(q);
    return [north];
  }

  @override
  List<Place> cachedSuggestions(String q, GeoPoint? p) =>
      matchingPlaces(known, q, p);
  @override
  void cancelSearch() {
    cancellations++;
  }

  @override
  void dispose() {}
}

class PendingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final responses = <Completer<http.StreamedResponse>>[];
  int aborted = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    final response = Completer<http.StreamedResponse>();
    responses.add(response);
    if (request is http.Abortable) {
      request.abortTrigger?.then((_) {
        aborted++;
        if (!response.isCompleted) {
          response.completeError(http.RequestAbortedException(request.url));
        }
      });
    }
    return response.future;
  }
}

Map<String, dynamic> searchFeature(String id, String country) => {
  'type': 'Feature',
  'geometry': {
    'type': 'Point',
    'coordinates': [105.85, 21.03],
  },
  'properties': {
    'osm_id': id,
    'osm_type': 'N',
    'name': 'Nhà hát Hà Nội',
    'countrycode': country,
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await f.load();
  });

  test(
    'Startup has no fixed pickup and requests current device position once',
    () async {
      final location = LocationStub();
      final b = BookingController(RepositoryStub(), locationService: location);
      expect(b.pickup, isNull);
      expect(b.results, isEmpty);
      await b.initialize();
      await b.initialize();
      expect(location.calls, 1);
      expect(b.pickup!.point.latitude, location.point.latitude);
      expect(b.deviceLocation!.accuracyMeters, 124);
      expect(b.locationAccuracyLabel, contains('124 m'));
      b.dispose();
    },
  );
  test('Opening in another city uses the new device coordinate', () async {
    for (final point in [south.point, north.point]) {
      final b = BookingController(
        RepositoryStub(),
        locationService: LocationStub()..point = point,
      );
      await b.initialize();
      expect(b.pickup!.point.cacheKey, point.cacheKey);
      b.dispose();
    }
  });
  test(
    'Denied startup keeps pickup empty and destination requires manual pickup',
    () async {
      final repo = RepositoryStub();
      final b = BookingController(
        repo,
        locationService: LocationStub()..denied = true,
      );
      await b.initialize();
      expect(b.pickup, isNull);
      await b.selectPlace(north);
      expect(b.editingPickup, true);
      expect(repo.routes, 0);
      expect(b.canConfirm, false);
      await b.selectPlace(south);
      expect(repo.routes, 1);
      expect(b.destination, same(north));
      b.dispose();
    },
  );
  testWidgets('Automatic GPS remains valid while typing a destination', (
    tester,
  ) async {
    final location = LocationStub()..pending = Completer<DeviceLocation>();
    final b = BookingController(RepositoryStub(), locationService: location);
    final job = b.initialize();
    b.openSearch();
    b.updateQuery('Hà Nội');
    location.pending!.complete(DeviceLocation(north.point, accuracyMeters: 6));
    await tester.pump();
    await job;
    expect(b.pickup!.point.cacheKey, north.point.cacheKey);
    expect(b.query, 'Hà Nội');
    expect(b.stage, BookingStage.search);
    b.dispose();
  });
  testWidgets(
    'Search dispatches at 180ms, updates cached suggestions instantly and cancels old work',
    (tester) async {
      final repo = RepositoryStub()..known = [north];
      final b = BookingController(repo);
      b.openSearch();
      b.updateQuery('phía Bắc');
      expect(b.results.single, same(north));
      await tester.pump(const Duration(milliseconds: 179));
      expect(repo.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.queries, ['phía Bắc']);
      b.updateQuery('');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.queries.length, 1);
      expect(b.searching, false);
      expect(repo.cancellations, greaterThan(1));
      b.dispose();
    },
  );
  test(
    'Search aborts the previous HTTP request and filters results to Vietnam',
    () async {
      final client = PendingClient();
      final repo = LiveBookingRepository(client: client);
      final old = repo.search('Nhà hát', null);
      final fresh = repo.search('Hà Nội', null);
      await Future<void>.delayed(Duration.zero);
      expect(client.aborted, 1);
      expect(client.requests.last.url.queryParameters['countrycode'], 'VN');
      client.responses.last.complete(
        http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'features': [
                  searchFeature('1', 'VN'),
                  searchFeature('2', 'LA'),
                ],
              }),
            ),
          ),
          200,
        ),
      );
      expect(await old, isEmpty);
      expect((await fresh).length, 1);
      expect(repo.cachedSuggestions('ha noi', null).single.countryCode, 'VN');
      repo.dispose();
    },
  );
  testWidgets('Search deadline includes waiting for HTTP headers', (
    tester,
  ) async {
    final client = PendingClient();
    final repo = LiveBookingRepository(client: client);
    final check = expectLater(
      repo.search('Bảo tàng', null),
      throwsA(isA<MapServiceException>()),
    );
    await tester.pump(const Duration(seconds: 7));
    await check;
    expect(client.aborted, 1);
    repo.dispose();
  });
  test(
    'Price tiers are continuous at 2,12,25km and transparent after rounding',
    () {
      for (final item in [
        (2.0, 31000),
        (12.0, 183000),
        (25.0, 374000),
        (25.005, 374000),
        (26.0, 387000),
        (300.0, 4032000),
      ]) {
        final r = TripRoute(
          points: [south.point, north.point],
          distanceMeters: item.$1 * 1000,
          durationSeconds: 500,
        );
        final price = RideType.standard.breakdown(r);
        expect(price.total, item.$2);
        expect(price.subtotal + price.rounding, price.total.toDouble());
        expect(
          price.lines.fold<int>(0, (sum, line) => sum + line.amount.round()) +
              price.rounding.round(),
          price.total,
        );
      }
    },
  );
  test('Long routes require special-trip acknowledgement, and a changed quote clears it', () async {
    final repo = RepositoryStub()
      ..meters = 1700000
      ..seconds = 120000;
    final b = BookingController(repo)..pickup = south;
    await b.selectPlace(north);
    expect(b.longDistance, true);
    expect(b.specialTrip, true);
    expect(b.canConfirm, false);
    expect(b.fare, 22652000);
    expect(formatDuration(repo.seconds), '33 giờ 20 phút');
    b.acceptSpecialTrip(true);
    expect(b.canConfirm, true);
    b.confirmRide();
    expect(b.stage, BookingStage.confirm);
    await b.loadRoute();
    expect(b.specialTripAccepted, false);
    expect(b.canConfirm, false);
    b.dispose();
  });
  test('35km changes service classification without claiming the operator accepts a trip', () async {
    final repo = RepositoryStub()..meters = 35000;
    final b = BookingController(repo)..pickup = south;
    await b.selectPlace(north);
    expect(b.longDistance, true);
    expect(b.specialTrip, false);
    expect(b.canConfirm, true);
    b.dispose();
  });
  test('Expired quote cannot be booked before a new quote is loaded', () async {
    final b = BookingController(RepositoryStub())..pickup = south;
    await b.selectPlace(north);
    b.confirmRide();
    b.quotedAt = DateTime.now().subtract(const Duration(minutes: 3));
    b.bookDemo();
    expect(b.stage, BookingStage.rides);
    expect(b.canConfirm, false);
    await b.loadRoute();
    expect(b.canConfirm, true);
    b.dispose();
  });
  test(
    'Outside Vietnam and equal pickup/destination are rejected before routing',
    () async {
      final repo = LiveBookingRepository(
        client: MockClient(
          (_) async => throw StateError('Must not call network'),
        ),
      );
      final foreign = Place(
        id: 'foreign',
        name: 'Foreign',
        address: '',
        point: north.point,
        countryCode: 'LA',
      );
      await expectLater(
        repo.route(south, foreign),
        throwsA(isA<MapServiceException>()),
      );
      await expectLater(
        repo.route(south, south),
        throwsA(isA<MapServiceException>()),
      );
      repo.dispose();
    },
  );
  test('No road near the pin keeps a specific recovery message', () async {
    final repo = LiveBookingRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters['radiuses'], '200;200');
        return http.Response('{"code":"NoSegment"}', 400);
      }),
    );
    await expectLater(
      repo.route(south, north),
      throwsA(
        isA<MapServiceException>().having(
          (e) => e.message,
          'message',
          contains('không gần đường ô tô'),
        ),
      ),
    );
    repo.dispose();
  });
  test('Long playback handles duplicate points and exact endpoints', () {
    final points = [
      south.point,
      south.point,
      ...List.generate(
        12000,
        (i) => GeoPoint(10.8 + i / 1200, 106.7 - i / 12000),
      ),
    ];
    final r = TripRoute(
      points: points,
      distanceMeters: 1500000,
      durationSeconds: 100000,
    );
    expect(r.pointAt(0), same(points.first));
    expect(r.pointAt(1), same(points.last));
    expect(r.pointAt(.5).latitude, closeTo(15.8, .05));
  });
  testWidgets('Pickup form with keyboard and 130% text fits a 320px phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BookingController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: rideTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: BookingScreen(
          repository: RepositoryStub(),
          locationService: LocationStub(),
          mapBuilder: (b) {
            controller = b;
            return const ColoredBox(color: Colors.grey);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.openSearch(pickupField: true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chọn vị trí hiện tại của bạn'),
      80,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Chọn vị trí hiện tại của bạn'), findsOneWidget);
    expect(find.text('Uber'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Current position button selects a fresh GPS coordinate', (
    tester,
  ) async {
    final location = LocationStub();
    late BookingController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: rideTheme(),
        home: BookingScreen(
          repository: RepositoryStub(),
          locationService: location,
          mapBuilder: (b) {
            controller = b;
            return const ColoredBox(color: Colors.grey);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.openSearch(pickupField: true);
    await tester.pumpAndSettle();
    location.point = north.point;
    await tester.tap(find.text('Chọn vị trí hiện tại của bạn'));
    await tester.pumpAndSettle();
    expect(location.calls, 2);
    expect(controller.pickup!.point.cacheKey, north.point.cacheKey);
    expect(controller.stage, BookingStage.home);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
