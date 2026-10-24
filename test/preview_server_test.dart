import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_lab/features/booking/data/live_booking_repository.dart';
import 'package:map_lab/features/booking/domain/ride_models.dart';

import '../tool/preview_server.dart';

void main() {
  test(
    'Local location rejects other origins, GET and missing intent header',
    () async {
      var reads = 0;
      final server = await startPreviewServer(
        port: 0,
        locationReader: () async {
          reads++;
          return {'source': 'test fixture'};
        },
      );
      addTearDown(() => server.close(force: true));
      final url = Uri.parse('http://127.0.0.1:${server.port}/__ride/location');
      for (final headers in [
        <String, String>{},
        {'Origin': 'https://other.example', 'X-Ride-Location': '1'},
        {
          'Origin': 'http://127.0.0.1:${server.port}',
          'X-Ride-Location': '1',
          'Sec-Fetch-Site': 'cross-site',
        },
      ]) {
        expect((await http.post(url, headers: headers)).statusCode, 403);
      }
      expect((await http.get(url)).statusCode, 403);
      expect(reads, 0);
      final response = await http.post(
        url,
        headers: {
          'Origin': 'http://127.0.0.1:${server.port}',
          'X-Ride-Location': '1',
        },
      );
      expect(response.statusCode, 200);
      expect(jsonDecode(response.body)['source'], 'test fixture');
      expect(response.headers['cache-control'], 'no-store');
      expect(
        response.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
      expect(reads, 1);
    },
  );

  test(
    'Location retries fetch a new fix and do not cache a previous coordinate',
    () async {
      var reads = 0;
      final server = await startPreviewServer(
        port: 0,
        locationReader: () async => {'sequence': ++reads},
      );
      addTearDown(() => server.close(force: true));
      final url = Uri.parse('http://127.0.0.1:${server.port}/__ride/location');
      final headers = {
        'Origin': 'http://127.0.0.1:${server.port}',
        'X-Ride-Location': '1',
      };
      for (final sequence in [1, 2]) {
        final response = await http.post(url, headers: headers);
        expect(jsonDecode(response.body)['sequence'], sequence);
      }
    },
  );

  test(
    'Unavailable OS location returns an error instead of a synthetic fix',
    () async {
      final server = await startPreviewServer(
        port: 0,
        locationReader: () async => throw TimeoutException('No OS location'),
      );
      addTearDown(() => server.close(force: true));
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/__ride/location'),
        headers: {
          'Origin': 'http://127.0.0.1:${server.port}',
          'X-Ride-Location': '1',
        },
      );
      expect(response.statusCode, 503);
      final body = jsonDecode(response.body) as Map;
      expect(body.containsKey('latitude'), isFalse);
      expect(body.containsKey('error'), isTrue);
    },
  );

  test(
    'Configured search endpoint works without forwarding device coordinates',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, '127.0.0.1');
        expect(request.url.path, '/__ride/geocoder/api/');
        expect(request.url.queryParameters.containsKey('lat'), isFalse);
        expect(request.url.queryParameters.containsKey('lon'), isFalse);
        expect(request.url.queryParameters['q'], 'Landmark 81');
        return http.Response('{"features":[]}', 200);
      });
      final repo = LiveBookingRepository(
        client: client,
        searchEndpoint: Uri.parse(
          'http://127.0.0.1:52341/__ride/geocoder/api/',
        ),
      );
      await repo.search('Landmark 81', const GeoPoint(10.8, 106.7));
      repo.dispose();
    },
  );
}
