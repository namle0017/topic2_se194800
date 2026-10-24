import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:map_lab/features/booking/domain/device_location.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_lab/core/app_theme.dart';

import 'fixtures/places.dart';

import 'package:map_lab/features/booking/data/live_booking_repository.dart';
import 'package:map_lab/features/booking/domain/ride_models.dart';
import 'package:map_lab/features/booking/presentation/booking_controller.dart';
import 'package:map_lab/features/booking/presentation/booking_screen.dart';

TripRoute sampleRoute() => TripRoute(
  points: [demoPickup.point, demoPlaces.first.point],
  distanceMeters: 4407.2,
  durationSeconds: 392.4,
);

class FakeRepository implements BookingRepository {
  final pendingRoutes = <Completer<TripRoute>>[];
  bool defer = false;
  Completer<Place>? reversePending;
  final searches = <String, Completer<List<Place>>>{};
  bool deferSearch = false;
  @override
  Future<TripRoute> route(Place pickup, Place destination) {
    if (!defer) return Future.value(sampleRoute());
    final pending = Completer<TripRoute>();
    pendingRoutes.add(pending);
    return pending.future;
  }

  @override
  Future<List<Place>> search(String query, GeoPoint? near) {
    if (!deferSearch) return Future.value(localPlaces(query));
    final pending = Completer<List<Place>>();
    searches[query] = pending;
    return pending.future;
  }

  @override
  Future<Place> reverse(GeoPoint point) async => reversePending == null
      ? Place(id: 'pin', name: 'Điểm đã chọn', address: 'Địa chỉ', point: point)
      : await reversePending!.future;
  @override
  void dispose() {}
}

BookingController fixtureController(
  BookingRepository repository, {
  DeviceLocationService? locationService,
}) =>
    BookingController(repository, locationService: locationService)
      ..pickup = demoPickup;

class FixtureLocation implements DeviceLocationService {
  @override
  Future<DeviceLocation> currentLocation() async =>
      DeviceLocation(demoPickup.point, accuracyMeters: 5);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await fonts.load();
  });

  test('Vietnamese search handles accents and all search terms', () {
    expect(localPlaces('san bay tan son').single.id, 'airport');
    expect(localPlaces('dinh doc lap').single.id, 'palace');
    expect(localPlaces('Landmark unrelated'), isEmpty);
  });

  test('Leaving pin mode cancels an in-flight address confirmation', () async {
    final repository = FakeRepository()..reversePending = Completer<Place>();
    final controller = fixtureController(repository);
    controller.openSearch();
    controller.openPin();
    controller.movePin(const GeoPoint(10.78, 106.71));
    final pending = controller.confirmPin();
    controller.back();
    repository.reversePending!.complete(demoPlaces.first);
    await pending;
    expect(controller.stage, BookingStage.search);
    expect(controller.destination, isNull);
    expect(controller.locating, isFalse);
    controller.dispose();
  });

  testWidgets('Late search results cannot replace a newer query', (
    tester,
  ) async {
    final repository = FakeRepository()..deferSearch = true;
    final controller = fixtureController(repository);
    controller.openSearch();
    controller.updateQuery('old query');
    await tester.pump(const Duration(milliseconds: 700));
    controller.updateQuery('new query');
    await tester.pump(const Duration(milliseconds: 700));
    repository.searches['new query']!.complete([demoPlaces[1]]);
    await tester.pump();
    repository.searches['old query']!.complete([demoPlaces[0]]);
    await tester.pump();
    expect(controller.results.single.id, 'airport');
    controller.dispose();
  });

  test('Fares use actual route data, minimums and whole VND rounding', () {
    expect(RideType.standard.fareFor(sampleRoute()), 68000);
    expect(RideType.comfort.fareFor(sampleRoute()), 75000);
    expect(RideType.xl.fareFor(sampleRoute()), 85000);
    final short = TripRoute(
      points: [demoPickup.point, demoPlaces.first.point],
      distanceMeters: 100,
      durationSeconds: 30,
    );
    expect(RideType.standard.fareFor(short), 31000);
    expect(formatVnd(1045000), '1.045.000 ₫');
  });

  test('Playback interpolates road distance and reaches exact endpoints', () {
    final route = TripRoute(
      points: const [GeoPoint(0, 0), GeoPoint(0, 1), GeoPoint(0, 4)],
      distanceMeters: 400000,
      durationSeconds: 1000,
    );
    expect(route.pointAt(0).longitude, 0);
    expect(route.pointAt(.5).longitude, closeTo(2, .001));
    expect(route.pointAt(1).longitude, 4);
  });

  test('Latest route wins when HTTP responses arrive out of order', () async {
    final repository = FakeRepository()..defer = true;
    final controller = fixtureController(repository);
    final first = controller.selectPlace(demoPlaces[0]);
    final second = controller.selectPlace(demoPlaces[1]);
    final fresh = TripRoute(
      points: [demoPickup.point, demoPlaces[1].point],
      distanceMeters: 7514,
      durationSeconds: 950,
    );
    repository.pendingRoutes[1].complete(fresh);
    await second;
    repository.pendingRoutes[0].complete(sampleRoute());
    await first;
    expect(controller.destination!.id, 'airport');
    expect(controller.tripRoute, same(fresh));
    expect(controller.loadingRoute, isFalse);
    controller.dispose();
  });

  test('Confirmation stays disabled while route is missing and reset invalidates pending route', () async {
    final repository = FakeRepository()..defer = true;
    final controller = fixtureController(repository);
    final future = controller.selectPlace(demoPlaces.first);
    controller.confirmRide();
    expect(controller.stage, BookingStage.rides);
    expect(controller.fare, isNull);
    controller.reset();
    repository.pendingRoutes.single.complete(sampleRoute());
    await future;
    expect(controller.stage, BookingStage.home);
    expect(controller.tripRoute, isNull);
    controller.dispose();
  });

  test(
    'Pin selection uses the exact coordinate and computes a fresh quote',
    () async {
      final controller = fixtureController(FakeRepository());
      controller.openSearch(pickupField: true);
      controller.openPin();
      controller.movePin(const GeoPoint(10.78, 106.70));
      await controller.confirmPin();
      expect(controller.pickup!.point.cacheKey, '10.7800000,106.7000000');
      expect(controller.stage, BookingStage.home);
      controller.editingPickup = false;
      await controller.selectPlace(demoPlaces.first);
      expect(controller.fare, 68000);
      controller.dispose();
    },
  );

  test(
    'OSRM response keeps road geometry and correct latitude/longitude order',
    () async {
      final repository = LiveBookingRepository(
        client: MockClient((request) async {
          expect(
            request.url.path,
            contains('106.7033,10.7767;106.7218,10.7951'),
          );
          final saved = jsonDecode(
            await File('test/fixtures/saigon.json').readAsString(),
          ) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [saved.values.first],
            }),
            200,
          );
        }),
      );
      final route = await repository.route(demoPickup, demoPlaces.first);
      expect(route.points.length, greaterThan(10));
      expect(route.points.first.latitude, closeTo(10.7767, .005));
      expect(route.points.first.longitude, closeTo(106.7033, .005));
      repository.dispose();
    },
  );

  test('Network failure never substitutes a fixed city route', () async {
    final repository = LiveBookingRepository(
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    await expectLater(
      repository.route(demoPickup, demoPlaces.first),
      throwsA(isA<MapServiceException>()),
    );
    repository.dispose();
  });

  test(
    'Reverse geocode preserves GPS/pin position instead of POI centroid',
    () async {
      final repository = LiveBookingRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Test',
                    'city': 'Saigon',
                    'osm_id': 123,
                  },
                  'geometry': {
                    'coordinates': [106.8, 10.8],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final place = await repository.reverse(const GeoPoint(10.7, 106.7));
      expect(place.point.latitude, 10.7);
      expect(place.point.longitude, 106.7);
      repository.dispose();
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Booking flow fits a ${width.toInt()} px phone and recomputes ride selection',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: rideTheme(),
            home: BookingScreen(
              repository: FakeRepository(),
              locationService: FixtureLocation(),
              mapBuilder: (_) => const ColoredBox(color: Color(0xFFEDEDED)),
            ),
          ),
        );
        expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('destination-search')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Landmark');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Landmark 81'));
        await tester.pumpAndSettle();
        expect(find.text('68.000 ₫'), findsOneWidget);
        await tester.tap(find.text('Comfort'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn Comfort'));
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận chuyến đi'), findsOneWidget);
        expect(find.text('75.000 ₫'), findsOneWidget);
        await tester.tap(find.text('Đặt chuyến demo'));
        await tester.pumpAndSettle();
        expect(find.text('Chuyến đi đã sẵn sàng'), findsOneWidget);
        await tester.tap(find.text('Chạy mô phỏng'));
        await tester.pump(const Duration(seconds: 26));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã đến nơi'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Chuyến đi mới'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
      },
    );
  }
}
