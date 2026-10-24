import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Local preview companion, never a public server. No coordinates are logged.
Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 52341 : int.parse(args.single);
  final server = await startPreviewServer(port: port);
  stdout.writeln('Ride preview: http://127.0.0.1:${server.port}/');
}

bool allowsDeviceLocationRequest(HttpRequest request, int port) =>
    request.method == 'POST' &&
    request.headers.value('origin') == 'http://127.0.0.1:$port' &&
    request.headers.value('x-ride-location') == '1' &&
    (request.headers.value('sec-fetch-site') == null ||
        request.headers.value('sec-fetch-site') == 'same-origin');

Future<HttpServer> startPreviewServer({
  required int port,
  String root = 'build/web',
  Future<Map<String, dynamic>> Function()? locationReader,
}) async {
  final rootDirectory = Directory(root).absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final upstream = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  Future<Map<String, dynamic>>? activeLocation;

  Future<Map<String, dynamic>> readLocation() async {
    if (activeLocation != null) return activeLocation!;
    final work = (locationReader ?? readWindowsLocation)();
    activeLocation = work;
    try {
      return await work;
    } finally {
      if (identical(activeLocation, work)) activeLocation = null;
    }
  }

  server.listen((request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    try {
      if (request.uri.path == '/__ride/location') {
        if (!allowsDeviceLocationRequest(request, server.port)) {
          response.statusCode = HttpStatus.forbidden;
        } else {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(await readLocation()));
        }
      } else if (request.uri.path == '/__ride/geocoder/api/') {
        final origin = request.headers.value('origin');
        final fetchSite = request.headers.value('sec-fetch-site');
        if (request.method != 'GET' ||
            (origin != null && origin != 'http://127.0.0.1:${server.port}') ||
            (fetchSite != null && fetchSite != 'same-origin')) {
          response.statusCode = HttpStatus.forbidden;
        } else {
          final query = request.uri.queryParameters['q']?.trim() ?? '';
          if (query.length < 2 || query.length > 200) {
            response.statusCode = HttpStatus.badRequest;
          } else {
            // Fixed provider and country scope; no arbitrary URL proxy. The
            // actual device coordinate is never forwarded to this provider.
            final url = Uri.https('photon.koalasec.org', '/api/', {
              'q': query,
              'limit': '8',
              'countrycode': 'VN',
              'bbox': '102.14,8.17,110.0,23.4',
            });
            final outgoing = await upstream.getUrl(url);
            outgoing.headers.set('User-Agent', 'PRM393-RideMapDemo/1.0');
            final result = await outgoing.close().timeout(
              const Duration(seconds: 5),
            );
            response.statusCode = result.statusCode;
            response.headers.contentType = ContentType.json;
            await response.addStream(
              result.timeout(const Duration(seconds: 5)),
            );
          }
        }
      } else if (request.method == 'GET' || request.method == 'HEAD') {
        final segments = request.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .toList();
        if (segments.any(
          (s) => s == '.' || s == '..' || s.contains('\\') || s.contains('/'),
        )) {
          response.statusCode = HttpStatus.forbidden;
        } else {
          final file = File(
            '${rootDirectory.path}/${segments.isEmpty ? 'index.html' : segments.join('/')}',
          );
          if (!await file.exists()) {
            response.statusCode = HttpStatus.notFound;
          } else {
            final resolved = await file.resolveSymbolicLinks();
            final rootResolved = await rootDirectory.resolveSymbolicLinks();
            if (!resolved.startsWith(
              '$rootResolved${Platform.pathSeparator}',
            )) {
              response.statusCode = HttpStatus.forbidden;
            } else {
              final extension = file.path.split('.').last;
              response.headers.set('Content-Type', switch (extension) {
                'html' => 'text/html; charset=utf-8',
                'js' => 'application/javascript; charset=utf-8',
                'json' => 'application/json; charset=utf-8',
                'wasm' => 'application/wasm',
                'css' => 'text/css; charset=utf-8',
                'png' => 'image/png',
                'svg' => 'image/svg+xml',
                'ttf' => 'font/ttf',
                'woff2' => 'font/woff2',
                _ => 'application/octet-stream',
              });
              if (request.method != 'HEAD') {
                await response.addStream(file.openRead());
              }
            }
          }
        }
      } else {
        response.statusCode = HttpStatus.methodNotAllowed;
      }
    } catch (_) {
      response.statusCode = HttpStatus.serviceUnavailable;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'error': 'Nguồn dữ liệu chưa sẵn sàng'}));
    } finally {
      await response.close();
    }
  }, onDone: () => upstream.close(force: true));
  return server;
}

Future<Map<String, dynamic>> readWindowsLocation() async {
  if (!Platform.isWindows) throw UnsupportedError('Windows preview only');
  final script = await File('tool/windows_location.ps1').readAsString();
  final process = await Process.start('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    script,
  ]);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.drain<void>();
  try {
    final code = await process.exitCode.timeout(const Duration(seconds: 19));
    final data = jsonDecode(await output) as Map<String, dynamic>;
    await errors;
    if (code != 0 || data['error'] != null) {
      throw StateError('Location unavailable');
    }
    return data;
  } on TimeoutException {
    process.kill();
    rethrow;
  }
}
