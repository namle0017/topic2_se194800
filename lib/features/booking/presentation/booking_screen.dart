import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/app_theme.dart';
import '../data/live_booking_repository.dart';
import '../domain/device_location.dart';
import '../domain/ride_models.dart';
import '../../map/foreground_tracker.dart';
import 'booking_controller.dart';
import 'components/ride_map.dart';
import 'components/booking_controls.dart';
import 'panels/home_panel.dart';
import 'panels/search_panel.dart';
import 'panels/pin_panel.dart';
import 'panels/ride_choice_panel.dart';
import 'panels/trip_panels.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    this.repository,
    this.locationService,
    this.foregroundTracker,
    this.now,
    this.mapBuilder,
  });
  final BookingRepository? repository;
  final DeviceLocationService? locationService;
  final ForegroundTracker? foregroundTracker;
  final DateTime Function()? now;

  /// Allows widget tests to exercise the booking flow without a platform map.
  final Widget Function(BookingController)? mapBuilder;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with WidgetsBindingObserver {
  late final BookingController booking;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    booking = BookingController(
      widget.repository ?? LiveBookingRepository(),
      locationService: widget.locationService,
      foregroundTracker: widget.foregroundTracker,
      now: widget.now,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(booking.initialize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(booking.resumeTracking());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(booking.pauseTracking());
    }
  }

  Future<void> _locate({bool selectPickup = false}) async {
    await booking.locate(selectPickup: selectPickup);
    if (!mounted || booking.locationFailure == null) return;
    final failure = booking.locationFailure!;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vị trí chưa sẵn sàng'),
        content: Text(failure.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Chọn trên bản đồ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      await _locate(selectPickup: selectPickup);
    } else if (retry == false) {
      FocusManager.instance.primaryFocus?.unfocus();
      booking.openSearch(pickupField: true);
      booking.openPin();
    }
  }

  double _sheetHeight(double height, double textScale) {
    final desired = switch (booking.stage) {
      BookingStage.home => 330.0,
      BookingStage.search => 560.0,
      BookingStage.pin => 230.0,
      BookingStage.rides => 443.0,
      BookingStage.confirm => 354.0,
      BookingStage.trip => 285.0,
      BookingStage.complete => 290.0,
    };
    return math.min(
      desired * math.min(textScale, 1.4),
      math.max(200, height - 150),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: booking,
    builder: (context, _) => PopScope(
      canPop: booking.stage == BookingStage.home,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) booking.back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sheetHeight = _sheetHeight(
              constraints.maxHeight,
              MediaQuery.textScalerOf(context).scale(1),
            );
            final motion = reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 380);
            final pinMode = booking.stage == BookingStage.pin;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: motion,
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: sheetHeight - 24,
                  child:
                      widget.mapBuilder?.call(booking) ??
                      RideMap(booking: booking),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 18,
                  left: 20,
                  right: 20,
                  child: PointerInterceptor(
                    child: Row(
                      children: [
                        if (booking.stage != BookingStage.home)
                          MapControlButton(
                            icon: Icons.arrow_back,
                            label: 'Quay lại',
                            onTap:
                                booking.stage == BookingStage.trip ||
                                    booking.stage == BookingStage.complete
                                ? booking.reset
                                : booking.back,
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .96),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: Color(0xFF087F5B),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Bản demo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (pinMode)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: sheetHeight - 24,
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          // 64 px artwork: the 59 px stem tip lands at map center.
                          offset: const Offset(0, -27),
                          child: const MapCenterPin(),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 18,
                  bottom: sheetHeight + 18,
                  child: PointerInterceptor(
                    child: MapControlButton(
                      icon: booking.tripRoute == null
                          ? Icons.my_location
                          : Icons.center_focus_strong,
                      label: booking.tripRoute == null
                          ? 'Vị trí của tôi'
                          : 'Xem toàn bộ tuyến',
                      busy: booking.locating,
                      onTap: () {
                        if (booking.tripRoute == null) {
                          _locate();
                        } else {
                          booking.recenter();
                        }
                      },
                    ),
                  ),
                ),
                if (booking.error != null &&
                    booking.stage != BookingStage.rides &&
                    booking.stage != BookingStage.search)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: sheetHeight + 76,
                    child: PointerInterceptor(
                      child: Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            booking.error!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: motion,
                  curve: Curves.easeInOutCubic,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: sheetHeight,
                  child: PointerInterceptor(
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      shadowColor: const Color(0x22000000),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 11),
                            Container(
                              width: 34,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD5D5D5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: reduceMotion(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 230),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: KeyedSubtree(
                                  key: ValueKey(booking.stage),
                                  child: switch (booking.stage) {
                                    BookingStage.home => HomePanel(
                                      booking,
                                      onLocate: _locate,
                                      onToggleTracking: () {
                                        if (booking.trackingRequested) {
                                          unawaited(booking.stopTracking());
                                        } else {
                                          unawaited(booking.startTracking());
                                        }
                                      },
                                    ),
                                    BookingStage.search => SearchPanel(
                                      key: ValueKey(booking.editingPickup),
                                      booking: booking,
                                      onUseCurrentLocation: () =>
                                          _locate(selectPickup: true),
                                    ),
                                    BookingStage.pin => PinPanel(booking),
                                    BookingStage.rides => RideChoicePanel(
                                      booking,
                                    ),
                                    BookingStage.confirm => ConfirmationPanel(
                                      booking,
                                    ),
                                    BookingStage.trip => TripPanel(booking),
                                    BookingStage.complete => CompletePanel(
                                      booking,
                                    ),
                                  },
                                ),
                              ),
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
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    booking.dispose();
    super.dispose();
  }
}
