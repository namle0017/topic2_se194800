import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/place_search.dart';
import '../data/geolocator_location_service.dart';
import '../domain/device_location.dart';
import '../domain/ride_models.dart';
import '../../map/foreground_tracker.dart';

enum BookingStage { home, search, pin, rides, confirm, trip, complete }

class BookingController extends ChangeNotifier {
  BookingController(
    this.repository, {
    DeviceLocationService? locationService,
    ForegroundTracker? foregroundTracker,
    DateTime Function()? now,
  }) : locationService = locationService ?? GeolocatorLocationService(),
       foregroundTracker = foregroundTracker ?? ForegroundTracker(),
       _now = now ?? DateTime.now {
    this.foregroundTracker.addListener(_onForegroundTrackerChanged);
  }
  final BookingRepository repository;
  final DeviceLocationService locationService;
  final ForegroundTracker foregroundTracker;
  final DateTime Function() _now;
  BookingStage stage = BookingStage.home;
  Place? pickup;
  Place? destination;
  TripRoute? tripRoute;
  DeviceLocation? deviceLocation;
  RideType selectedRide = RideType.standard;
  List<Place> results = [];
  final List<Place> recentPlaces = [];
  bool editingPickup = false;
  bool searching = false;
  bool loadingRoute = false;
  bool locating = false;
  bool specialTripAccepted = false;
  LocationFailure? locationFailure;
  String? locationNotice;
  String? error;
  String query = '';
  GeoPoint? pendingPin;
  Place? pinAddress;
  bool resolvingPin = false;
  double simulationProgress = 0;
  bool simulationRunning = false;
  DateTime? departureTime;
  DateTime? quotedAt;
  int cameraRevision = 0;
  Timer? _debounce, _simulation, _pinDebounce, _quoteExpiry;
  int _pinVersion = 0, _pointVersion = 0, _searchVersion = 0, _routeVersion = 0;
  bool _disposed = false, _initialized = false, _automaticLocation = false;
  bool _trackingRequested = false;
  DateTime? _lastTrackedTimestamp, _lastLiveRouteAt;
  GeoPoint? _lastTrackedPoint, _lastLiveRoutePoint;

  // A country overview is a viewport, never a synthetic pickup/device position.
  GeoPoint get mapCenter =>
      (stage == BookingStage.pin ? pendingPin : null) ??
      (tracking ? deviceLocation?.point : null) ??
      pickup?.point ??
      deviceLocation?.point ??
      const GeoPoint(16, 106);
  bool get hasPickup => pickup != null;
  String get pickupLabel =>
      pickup?.name ?? (locating ? 'Đang lấy vị trí của bạn…' : 'Chọn điểm đón');
  String get locationAccuracyLabel {
    final accuracy = deviceLocation?.accuracyMeters;
    return accuracy != null && accuracy.isFinite && accuracy > 0
        ? '${deviceLocation?.sourceLabel == null ? '' : '${deviceLocation!.sourceLabel} · '}Sai số thiết bị báo: ${accuracy.ceil()} m · có thể chỉnh pin'
        : 'Lấy vị trí từ thiết bị';
  }

  bool get tracking => foregroundTracker.isTracking;
  bool get trackingRequested => _trackingRequested;
  String get trackingStatusLabel {
    final failure = foregroundTracker.error;
    if (failure != null) return failure;
    final location = deviceLocation;
    if (tracking && location?.timestamp == null) {
      return 'Đang chờ cập nhật GPS mới…';
    }
    if (location?.timestamp != null) {
      final accuracy = location!.accuracyMeters.isFinite
          ? '${location.accuracyMeters.ceil()} m'
          : 'không rõ';
      return '${location.sourceLabel ?? 'GPS thiết bị'} · sai số $accuracy · ${formatTime(location.timestamp!)}';
    }
    return 'Theo dõi GPS đang tắt';
  }

  bool get longDistance => (tripRoute?.kilometers ?? 0) >= 35;
  // Demo review thresholds; these are not a claim about any operator's limits.
  bool get specialTrip =>
      (tripRoute?.kilometers ?? 0) >= 300 ||
      (tripRoute?.durationSeconds ?? 0) >= 28800;
  bool get quoteExpired =>
      quotedAt != null &&
      DateTime.now().difference(quotedAt!) >= const Duration(minutes: 2);
  bool get canConfirm =>
      tripRoute != null &&
      !loadingRoute &&
      !quoteExpired &&
      (!specialTrip || specialTripAccepted);
  int? get fare => tripRoute == null ? null : selectedRide.fareFor(tripRoute!);
  DateTime? get arrival => tripRoute == null
      ? null
      : (departureTime ?? DateTime.now()).add(
          Duration(seconds: tripRoute!.durationSeconds.ceil()),
        );

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startTracking() async {
    _trackingRequested = true;
    _emit();
    await foregroundTracker.start();
    _emit();
  }

  Future<void> stopTracking() async {
    _trackingRequested = false;
    _lastLiveRouteAt = null;
    _lastLiveRoutePoint = null;
    _emit();
    await foregroundTracker.stop();
    _emit();
  }

  Future<void> pauseTracking() async {
    if (!_trackingRequested) return;
    await foregroundTracker.stop();
    _emit();
  }

  Future<void> resumeTracking() async {
    if (!_trackingRequested || _disposed) return;
    await foregroundTracker.start();
    _emit();
  }

  void _onForegroundTrackerChanged() {
    if (_disposed) return;
    final position = foregroundTracker.latest;
    if (position == null) {
      _emit();
      return;
    }
    final point = GeoPoint(position.latitude, position.longitude);
    if (_lastTrackedTimestamp == position.timestamp &&
        _lastTrackedPoint?.cacheKey == point.cacheKey) {
      _emit();
      return;
    }
    _lastTrackedTimestamp = position.timestamp;
    _lastTrackedPoint = point;
    deviceLocation = DeviceLocation(
      point,
      accuracyMeters: position.accuracy,
      sourceLabel: position.isMocked ? 'GPS mô phỏng' : 'GPS thiết bị',
      timestamp: position.timestamp,
      isMocked: position.isMocked,
    );
    locationNotice = locationAccuracyLabel;
    cameraRevision++;

    if (pickup?.id == 'device-location') {
      pickup = Place(
        id: 'device-location',
        name: 'Vị trí của bạn',
        address: position.isMocked
            ? 'Dữ liệu thử từ thiết bị'
            : 'Vị trí thiết bị',
        point: point,
      );
      final movedEnough =
          _lastLiveRoutePoint == null ||
          _lastLiveRoutePoint!.distanceTo(point) >= 50;
      final waitedEnough =
          _lastLiveRouteAt == null ||
          _now().difference(_lastLiveRouteAt!) >= const Duration(seconds: 10);
      if (destination != null && movedEnough && waitedEnough) {
        _lastLiveRoutePoint = point;
        _lastLiveRouteAt = _now();
        unawaited(loadRoute());
      }
    }
    _emit();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await locate(automatic: true);
  }

  List<Place> _suggestions(String value) {
    final cached = repository is LivePlaceSearch
        ? (repository as LivePlaceSearch).cachedSuggestions(
            value,
            pickup?.point,
          )
        : <Place>[];
    final unique = <String, Place>{
      for (final p in [...recentPlaces, ...cached]) p.id: p,
    };
    return matchingPlaces(unique.values, value, pickup?.point);
  }

  void _cancelSearch() {
    _debounce?.cancel();
    if (repository is LivePlaceSearch) {
      (repository as LivePlaceSearch).cancelSearch();
    }
  }

  void openSearch({bool pickupField = false}) {
    final previousLocationFailure = locationFailure;
    _cancelPointWork(preserveAutomatic: true);
    locationFailure = previousLocationFailure;
    _cancelSearch();
    _searchVersion++;
    _routeVersion++;
    loadingRoute = false;
    editingPickup = pickupField;
    stage = BookingStage.search;
    query = '';
    searching = false;
    results = _suggestions('');
    error = null;
    _emit();
  }

  void updateQuery(String value) {
    query = value;
    _cancelSearch();
    final version = ++_searchVersion;
    results = _suggestions(value);
    searching = value.trim().length >= 2;
    error = null;
    _emit();
    if (searching) {
      _debounce = Timer(
        const Duration(milliseconds: 180),
        () => _search(value, version),
      );
    }
  }

  Future<void> _search(String value, int version) async {
    try {
      final remote = await repository.search(value, pickup?.point);
      if (_disposed || version != _searchVersion) return;
      final local = _suggestions(value);
      results = [
        ...remote,
        ...local.where(
          (p) => !remote.any(
            (r) =>
                r.id == p.id ||
                (r.point.distanceTo(p.point) < 80 &&
                    normalizeQuery(r.name) == normalizeQuery(p.name)),
          ),
        ),
      ];
    } catch (e) {
      if (_disposed || version != _searchVersion) return;
      error = e.toString();
    }
    if (_disposed || version != _searchVersion) return;
    searching = false;
    _emit();
  }

  Future<void> selectPlace(Place place) async {
    _cancelPointWork();
    _cancelSearch();
    _searchVersion++;
    searching = false;
    error = null;
    recentPlaces.removeWhere((p) => p.id == place.id);
    recentPlaces.insert(0, place);
    if (recentPlaces.length > 10) recentPlaces.removeLast();
    if (editingPickup) {
      pickup = place;
    } else {
      destination = place;
    }
    pendingPin = null;
    cameraRevision++;
    if (destination != null && pickup != null) {
      await loadRoute();
    } else if (pickup == null) {
      editingPickup = true;
      stage = BookingStage.search;
      query = '';
      results = _suggestions('');
      _emit();
    } else {
      stage = BookingStage.home;
      _emit();
    }
  }

  Future<void> loadRoute() async {
    final target = destination, origin = pickup;
    if (target == null || origin == null) return;
    final version = ++_routeVersion;
    stage = BookingStage.rides;
    tripRoute = null;
    loadingRoute = true;
    departureTime = null;
    quotedAt = null;
    specialTripAccepted = false;
    _quoteExpiry?.cancel();
    error = null;
    _emit();
    try {
      final route = await repository.route(origin, target);
      if (_disposed || version != _routeVersion) return;
      tripRoute = route;
      quotedAt = DateTime.now();
      _quoteExpiry = Timer(const Duration(minutes: 2), _emit);
      cameraRevision++;
    } catch (e) {
      if (_disposed || version != _routeVersion) return;
      error = e.toString();
    }
    if (_disposed || version != _routeVersion) return;
    loadingRoute = false;
    _emit();
  }

  void openPin() {
    _cancelPointWork();
    _cancelSearch();
    _searchVersion++;
    _routeVersion++;
    loadingRoute = false;
    searching = false;
    stage = BookingStage.pin;
    pendingPin = (editingPickup ? pickup : destination)?.point ?? mapCenter;
    pinAddress = editingPickup ? pickup : destination;
    cameraRevision++;
    error = null;
    _emit();
  }

  void movePin(GeoPoint point) {
    if (pendingPin?.cacheKey == point.cacheKey) return;
    _pointVersion++;
    _automaticLocation = false;
    locating = false;
    locationFailure = null;
    locationNotice = null;
    pendingPin = point;
    pinAddress = null;
    resolvingPin = true;
    _pinDebounce?.cancel();
    final version = ++_pinVersion;
    _pinDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final address = await repository.reverse(point);
        if (_disposed || version != _pinVersion || stage != BookingStage.pin) {
          return;
        }
        pinAddress = address;
      } catch (_) {
        /* Pin remains selectable without an address. */
      }
      if (_disposed || version != _pinVersion || stage != BookingStage.pin) {
        return;
      }
      resolvingPin = false;
      _emit();
    });
    _emit();
  }

  Future<void> confirmPin() async {
    final point = pendingPin;
    if (point == null || locating) return;
    final version = ++_pointVersion;
    _pinDebounce?.cancel();
    locating = true;
    _emit();
    Place place;
    try {
      place = pinAddress?.point.cacheKey == point.cacheKey
          ? pinAddress!
          : await repository.reverse(point);
    } catch (_) {
      place = Place(
        id: 'pin-${point.cacheKey}',
        name: 'Điểm đã chọn',
        address: '',
        point: point,
      );
    }
    if (_disposed || version != _pointVersion || stage != BookingStage.pin) {
      return;
    }
    locating = false;
    await selectPlace(
      Place(
        id: place.id,
        name: place.name,
        address: place.address,
        point: point,
        countryCode: place.countryCode,
      ),
    );
  }

  Future<void> locate({
    bool selectPickup = false,
    bool automatic = false,
  }) async {
    if (locating) return;
    final version = ++_pointVersion;
    _automaticLocation = automatic;
    locating = true;
    locationFailure = null;
    locationNotice = null;
    _emit();
    try {
      final location = await locationService.currentLocation();
      if (_disposed || version != _pointVersion) return;
      deviceLocation = location;
      _automaticLocation = false;
      final point = location.point;
      var place = Place(
        id: 'device-location',
        name: 'Vị trí của bạn',
        address: 'Vị trí thiết bị',
        point: point,
      );
      locating = false;
      locationNotice = locationAccuracyLabel;
      cameraRevision++;
      final pinMode = stage == BookingStage.pin;
      if (pinMode) {
        _pinDebounce?.cancel();
        _pinVersion++;
        resolvingPin = false;
        pendingPin = point;
        pinAddress = place;
      } else {
        pickup = place;
        if (selectPickup) {
          _cancelSearch();
          _searchVersion++;
          searching = false;
          stage = BookingStage.home;
        }
      }
      _emit();
      final routeWork = !pinMode && destination != null
          ? loadRoute()
          : Future<void>.value();
      try {
        final address = await repository.reverse(point);
        place = Place(
          id: 'device-location',
          name: 'Vị trí của bạn',
          address:
              'Gần ${address.name}${address.address.isEmpty ? '' : ' · ${address.address}'}',
          point: point,
          countryCode: address.countryCode,
        );
      } catch (_) {
        /* Keep exact device coordinates when the address is unavailable. */
      }
      if (_disposed || version != _pointVersion) return;
      if (stage == BookingStage.pin) {
        if (pendingPin?.cacheKey == point.cacheKey) pinAddress = place;
      } else if (pickup?.point.cacheKey == point.cacheKey) {
        pickup = place;
      }
      _emit();
      await routeWork;
    } catch (e) {
      if (_disposed || version != _pointVersion) return;
      locationFailure = e is LocationFailure
          ? e
          : const LocationFailure(
              LocationFailureKind.unavailable,
              'Chưa lấy được vị trí. Thử lại hoặc chọn điểm đón trên bản đồ.',
            );
    }
    if (_disposed || version != _pointVersion) return;
    _automaticLocation = false;
    locating = false;
    _emit();
  }

  void acceptSpecialTrip(bool value) {
    specialTripAccepted = value;
    _emit();
  }

  void chooseRide(RideType ride) {
    selectedRide = ride;
    _emit();
  }

  void recenter() {
    cameraRevision++;
    _emit();
  }

  void confirmRide() {
    if (!canConfirm) return;
    stage = BookingStage.confirm;
    cameraRevision++;
    _emit();
  }

  void bookDemo() {
    if (!canConfirm) {
      if (quoteExpired) stage = BookingStage.rides;
      _emit();
      return;
    }
    stage = BookingStage.trip;
    simulationProgress = 0;
    departureTime = DateTime.now();
    _quoteExpiry?.cancel();
    _emit();
  }

  void startSimulation() {
    if (simulationRunning || stage != BookingStage.trip) return;
    simulationRunning = true;
    _simulation = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      simulationProgress = (timer.tick / 250).clamp(0, 1);
      if (simulationProgress >= 1) {
        _simulation?.cancel();
        simulationRunning = false;
        stage = BookingStage.complete;
      }
      _emit();
    });
    _emit();
  }

  void back() {
    _cancelPointWork();
    _cancelSearch();
    _searchVersion++;
    _routeVersion++;
    loadingRoute = false;
    searching = false;
    error = null;
    stage = switch (stage) {
      BookingStage.confirm => BookingStage.rides,
      BookingStage.pin => BookingStage.search,
      BookingStage.search =>
        destination == null ? BookingStage.home : BookingStage.rides,
      _ => BookingStage.home,
    };
    if (stage == BookingStage.home) {
      destination = null;
      tripRoute = null;
      _quoteExpiry?.cancel();
    }
    if (stage == BookingStage.rides &&
        tripRoute == null &&
        pickup != null &&
        destination != null) {
      unawaited(loadRoute());
    }
    cameraRevision++;
    _emit();
  }

  void reset() {
    _cancelPointWork();
    _cancelSearch();
    _simulation?.cancel();
    _quoteExpiry?.cancel();
    _routeVersion++;
    _searchVersion++;
    stage = BookingStage.home;
    destination = null;
    tripRoute = null;
    selectedRide = RideType.standard;
    simulationRunning = false;
    simulationProgress = 0;
    departureTime = null;
    quotedAt = null;
    specialTripAccepted = false;
    pendingPin = null;
    pinAddress = null;
    loadingRoute = false;
    searching = false;
    error = null;
    cameraRevision++;
    _emit();
  }

  void _cancelPointWork({bool preserveAutomatic = false}) {
    _pinDebounce?.cancel();
    _pinVersion++;
    resolvingPin = false;
    if (preserveAutomatic && _automaticLocation) return;
    _pointVersion++;
    _automaticLocation = false;
    locating = false;
    locationFailure = null;
    locationNotice = null;
  }

  @override
  void dispose() {
    _disposed = true;
    foregroundTracker.removeListener(_onForegroundTrackerChanged);
    foregroundTracker.dispose();
    _cancelSearch();
    _simulation?.cancel();
    _pinDebounce?.cancel();
    _quoteExpiry?.cancel();
    repository.dispose();
    super.dispose();
  }
}
