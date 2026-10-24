import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/app_theme.dart';
import '../../domain/ride_models.dart';
import '../booking_controller.dart';
import 'car_artwork.dart';

class RideMap extends StatefulWidget {
  const RideMap({super.key, required this.booking});
  final BookingController booking;
  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> with SingleTickerProviderStateMixin {
  MapLibreMapController? _map;
  String? _style;
  bool _ready = false;
  bool _updating = false;
  bool _dirty = false;
  int _revision = -1;
  int _attempt = 0;
  String? _failure;
  TripRoute? _drawnRoute;
  late final AnimationController _routeReveal;
  Timer? _loadTimeout;
  Timer? _resizeFit;
  Size? _viewSize;
  String? _routeSignature;
  String? _stopSignature;
  String? _carSignature;

  BookingController get booking => widget.booking;
  LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);
  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };
  Map<String, dynamic> _point(GeoPoint p, Map<String, dynamic> properties) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': p.coordinates},
    'properties': properties,
  };

  @override
  void initState() {
    super.initState();
    _routeReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_scheduleSync);
    booking.addListener(_changed);
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map/ride_style.json');
      if (mounted) setState(() => _style = style);
      _loadTimeout = Timer(const Duration(seconds: 18), () {
        if (mounted && !_ready) {
          setState(
            () => _failure = 'Chưa tải được bản đồ. Kiểm tra kết nối mạng.',
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failure = 'Chưa tải được giao diện bản đồ.');
    }
  }

  void _changed() {
    if (!_ready) return;
    if (_drawnRoute != booking.tripRoute) {
      _drawnRoute = booking.tripRoute;
      if (_drawnRoute != null &&
          _drawnRoute!.points.length < 2500 &&
          !reduceMotion(context)) {
        _routeReveal.forward(from: 0);
      } else {
        _routeReveal.value = 1;
      }
    }
    _scheduleSync();
    if (_revision != booking.cameraRevision) {
      _revision = booking.cameraRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCamera();
      });
    }
  }

  Future<void> _styleLoaded() async {
    final map = _map;
    if (map == null) return;
    try {
      for (final kind in ['pickup', 'destination', 'car']) {
        final icon = await createMapIcon(kind);
        final bytes = await icon.toByteData(format: ui.ImageByteFormat.png);
        icon.dispose();
        if (!mounted) return;
        await map.addImage('ride-demo-$kind', bytes!.buffer.asUint8List());
      }
      for (final id in ['route', 'stops', 'cars']) {
        await map.addGeoJsonSource(id, _collection([]));
      }
      await map.addLineLayer(
        'route',
        'route-outline',
        const LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 9,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await map.addLineLayer(
        'route',
        'route-ink',
        const LineLayerProperties(
          lineColor: '#000000',
          lineWidth: 4.5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await map.addSymbolLayer(
        'cars',
        'cars-symbols',
        const SymbolLayerProperties(
          iconImage: 'ride-demo-car',
          iconSize: .85,
          iconRotate: ['get', 'rotation'],
          iconRotationAlignment: 'map',
          iconAllowOverlap: true,
        ),
        enableInteraction: false,
      );
      await map.addSymbolLayer(
        'stops',
        'stop-symbols',
        const SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: .8,
          iconAllowOverlap: true,
          textField: ['get', 'label'],
          textSize: 12,
          textColor: '#000000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 4,
          textAnchor: 'bottom',
          textOffset: [0, -1.65],
          textFont: ['Noto Sans Regular'],
          textAllowOverlap: true,
        ),
        enableInteraction: false,
      );
      if (!mounted) return;
      _loadTimeout?.cancel();
      setState(() {
        _ready = true;
        _failure = null;
      });
      _drawnRoute = booking.tripRoute;
      _routeReveal.value = 1;
      _changed();
    } catch (_) {
      if (mounted) {
        setState(() => _failure = 'Chưa dựng được bản đồ. Nhấn để thử lại.');
      }
    }
  }

  void _scheduleSync() {
    _dirty = true;
    if (!_updating && _ready) unawaited(_sync());
  }

  Future<void> _sync() async {
    _updating = true;
    final motionReduced = reduceMotion(context);
    try {
      while (_dirty && mounted && _ready) {
        _dirty = false;
        final route = booking.tripRoute;
        final pinMode = booking.stage == BookingStage.pin;
        final points = route == null
            ? <GeoPoint>[]
            : route.points
                  .take(
                    math.max(
                      2,
                      (route.points.length *
                              Curves.easeOutCubic.transform(_routeReveal.value))
                          .ceil(),
                    ),
                  )
                  .toList();
        final routeSignature =
            '${identityHashCode(route)}:${points.length}:$pinMode';
        if (_routeSignature != routeSignature) {
          await _map!.setGeoJsonSource(
            'route',
            _collection([
              if (points.length >= 2 && !pinMode)
                {
                  'type': 'Feature',
                  'properties': <String, dynamic>{},
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': points.map((p) => p.coordinates).toList(),
                  },
                },
            ]),
          );
          _routeSignature = routeSignature;
        }
        final stopSignature =
            '${booking.pickup?.point.cacheKey}:${booking.destination?.point.cacheKey}:${booking.destination?.name}:${booking.tracking}:${booking.deviceLocation?.point.cacheKey}:$pinMode';
        if (_stopSignature != stopSignature) {
          await _map!.setGeoJsonSource(
            'stops',
            _collection([
              if (!pinMode && booking.hasPickup)
                _point(booking.pickup!.point, {
                  'icon': 'ride-demo-pickup',
                  'label': 'Điểm đón',
                }),
              if (!pinMode && booking.destination != null)
                _point(booking.destination!.point, {
                  'icon': 'ride-demo-destination',
                  'label': booking.destination!.name,
                }),
              if (!pinMode &&
                  booking.tracking &&
                  booking.deviceLocation != null &&
                  booking.deviceLocation!.point.cacheKey !=
                      booking.pickup?.point.cacheKey)
                _point(booking.deviceLocation!.point, {
                  'icon': 'ride-demo-pickup',
                  'label': 'GPS trực tiếp',
                }),
            ]),
          );
          _stopSignature = stopSignature;
        }
        final cars = <Map<String, dynamic>>[];
        if (!pinMode &&
            route != null &&
            (booking.stage == BookingStage.trip ||
                booking.stage == BookingStage.complete)) {
          final progress = motionReduced && booking.simulationRunning
              ? 0.0
              : booking.simulationProgress;
          final p = route.pointAt(progress);
          final next = route.pointAt((progress + .015).clamp(0, 1));
          final bearing =
              math.atan2(
                (next.longitude - p.longitude) *
                    math.cos(p.latitude * math.pi / 180),
                next.latitude - p.latitude,
              ) *
              180 /
              math.pi;
          cars.add(_point(p, {'rotation': bearing}));
        } else if (!pinMode && booking.hasPickup) {
          // Fictional drivers only, generated around the actual chosen pickup.
          final origin = booking.pickup!.point;
          for (final car in [
            (180.0, 250.0, 35),
            (-260.0, -160.0, 35),
            (90.0, -310.0, 125),
            (400.0, 120.0, 35),
          ]) {
            final p = GeoPoint(
              origin.latitude + car.$1 / 111320,
              origin.longitude +
                  car.$2 / (111320 * math.cos(origin.latitude * math.pi / 180)),
            );
            cars.add(_point(p, {'rotation': car.$3}));
          }
        }
        final carSignature =
            '${booking.stage}:${booking.pickup?.point.cacheKey}:${booking.simulationProgress.toStringAsFixed(3)}:$pinMode';
        if (_carSignature != carSignature) {
          await _map!.setGeoJsonSource('cars', _collection(cars));
          _carSignature = carSignature;
        }
      }
    } catch (_) {
      // A platform view can be disposed while an in-flight style update completes.
      if (mounted && _ready) {
        setState(() => _failure = 'Bản đồ chưa cập nhật được. Thử tải lại.');
      }
    } finally {
      _updating = false;
    }
  }

  Future<void> _fitCamera() async {
    final map = _map;
    if (!_ready || map == null) return;
    final route = booking.tripRoute;
    CameraUpdate camera;
    if (booking.stage == BookingStage.pin) {
      camera = CameraUpdate.newLatLngZoom(
        _latLng(booking.mapCenter),
        booking.hasPickup ||
                booking.deviceLocation != null ||
                booking.pinAddress != null
            ? 16.5
            : 4.4,
      );
    } else if (booking.tracking && booking.deviceLocation != null) {
      camera = CameraUpdate.newLatLngZoom(
        _latLng(booking.deviceLocation!.point),
        16.5,
      );
    } else if (route != null) {
      final latitudes = route.points.map((p) => p.latitude);
      final longitudes = route.points.map((p) => p.longitude);
      camera = CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            latitudes.reduce(math.min),
            longitudes.reduce(math.min),
          ),
          northeast: LatLng(
            latitudes.reduce(math.max),
            longitudes.reduce(math.max),
          ),
        ),
        left: 55,
        right: 55,
        top: 95,
        bottom: 55,
      );
    } else {
      camera = CameraUpdate.newLatLngZoom(
        _latLng(booking.mapCenter),
        booking.hasPickup ? 14.8 : 4.4,
      );
    }
    if (reduceMotion(context)) {
      await map.moveCamera(camera);
    } else {
      await map.animateCamera(
        camera,
        duration: const Duration(milliseconds: 700),
      );
    }
  }

  void _cameraIdle() {
    if (booking.stage != BookingStage.pin || !_ready) return;
    final target = _map?.cameraPosition?.target;
    if (target != null) {
      booking.movePin(GeoPoint(target.latitude, target.longitude));
    }
  }

  void _retry() {
    _loadTimeout?.cancel();
    _ready = false;
    _revision = -1;
    _routeSignature = null;
    _stopSignature = null;
    _carSignature = null;
    setState(() {
      _failure = null;
      _attempt++;
    });
    _loadStyle();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_viewSize != size) {
        _viewSize = size;
        _resizeFit?.cancel();
        _resizeFit = Timer(const Duration(milliseconds: 100), () {
          if (mounted) _fitCamera();
        });
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1F2F1)),
          if (_style != null)
            MapLibreMap(
              key: ValueKey(_attempt),
              styleString: _style!,
              initialCameraPosition: CameraPosition(
                target: _latLng(booking.mapCenter),
                zoom: booking.hasPickup ? 14.8 : 4.4,
              ),
              onMapCreated: (controller) => _map = controller,
              onStyleLoadedCallback: _styleLoaded,
              trackCameraPosition: true,
              onCameraIdle: _cameraIdle,
              onMapClick: (_, point) {
                if (booking.stage == BookingStage.pin) {
                  _map?.animateCamera(
                    CameraUpdate.newLatLng(point),
                    duration: Duration(
                      milliseconds: reduceMotion(context) ? 0 : 300,
                    ),
                  );
                }
              },
              compassEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: const math.Point(8, 55),
              webPreserveDrawingBuffer: true,
            ),
          if (!_ready && _failure == null)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              ),
            ),
          if (_failure != null)
            Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _retry,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined),
                        const SizedBox(height: 8),
                        Text(_failure!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                          'Tải lại bản đồ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  void dispose() {
    booking.removeListener(_changed);
    _loadTimeout?.cancel();
    _resizeFit?.cancel();
    _routeReveal.dispose();
    super.dispose();
  }
}
