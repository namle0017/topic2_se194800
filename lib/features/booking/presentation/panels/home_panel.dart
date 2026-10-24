import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';
import '../components/booking_controls.dart';

class HomePanel extends StatelessWidget {
  const HomePanel(
    this.b, {
    super.key,
    required this.onLocate,
    required this.onToggleTracking,
  });
  final BookingController b;
  final VoidCallback onLocate;
  final VoidCallback onToggleTracking;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bạn muốn đi đâu?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 14),
        Material(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: const ValueKey('destination-search'),
            onTap: () => b.openSearch(),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                children: [
                  Icon(Icons.search, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nhập điểm đến',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: () => b.openSearch(pickupField: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const StopDot(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b.hasPickup ? 'Đón tại ${b.pickupLabel}' : b.pickupLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 20, color: muted),
              ],
            ),
          ),
        ),
        if (b.deviceLocation != null &&
            (b.deviceLocation!.accuracyMeters > 25 ||
                !b.deviceLocation!.accuracyMeters.isFinite) &&
            b.pickup?.point.cacheKey == b.deviceLocation!.point.cacheKey)
          TextButton.icon(
            onPressed: () {
              b.openSearch(pickupField: true);
              b.openPin();
            },
            icon: const Icon(Icons.location_on_outlined, size: 17),
            label: Text(
              b.locationAccuracyLabel,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        const Divider(),
        if (!b.hasPickup)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: b.locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            title: const Text(
              'Chọn vị trí hiện tại của bạn',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              b.locationFailure?.message ?? 'Cho phép vị trí để tìm điểm đón.',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: b.locating ? null : onLocate,
          ),
        if (!b.hasPickup && !b.locating)
          TextButton.icon(
            onPressed: () => b.openSearch(pickupField: true),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Tìm địa chỉ điểm đón'),
          ),
        if (!kIsWeb)
          ListTile(
            key: const ValueKey('foreground-tracking-control'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              b.trackingRequested ? Icons.gps_off : Icons.gps_fixed,
            ),
            title: Text(
              b.trackingRequested
                  ? 'Dừng theo dõi GPS'
                  : 'Theo dõi GPS thời gian thực',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              b.trackingStatusLabel,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: onToggleTracking,
          ),
        for (final place
            in b.recentPlaces.where((p) => p.id != b.pickup?.id).take(2))
          PlaceResultRow(
            place: place,
            onTap: () {
              b.editingPickup = false;
              b.selectPlace(place);
            },
            compact: true,
          ),
      ],
    ),
  );
}
