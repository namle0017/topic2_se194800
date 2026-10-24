import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';
import '../../domain/ride_models.dart';

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: const Color(0x33000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: label,
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 23),
      padding: const EdgeInsets.all(13),
    ),
  );
}

class MapCenterPin extends StatelessWidget {
  const MapCenterPin({super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: ink,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
        ),
        child: const Center(
          child: Icon(Icons.circle, color: Colors.white, size: 12),
        ),
      ),
      Container(height: 23, width: 3, color: ink),
      Container(
        height: 5,
        width: 13,
        decoration: BoxDecoration(
          color: ink.withValues(alpha: .17),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ],
  );
}

class StopDot extends StatelessWidget {
  const StopDot({super.key, this.destination = false});
  final bool destination;
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: ink,
      shape: destination ? BoxShape.rectangle : BoxShape.circle,
    ),
    child: destination
        ? null
        : Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
  );
}

class PlaceResultRow extends StatelessWidget {
  const PlaceResultRow({
    super.key,
    required this.place,
    required this.onTap,
    this.compact = false,
  });
  final Place place;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 11 : 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              place.id == 'airport'
                  ? Icons.flight
                  : place.id == 'landmark'
                  ? Icons.apartment
                  : Icons.place_outlined,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  place.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (compact) const Icon(Icons.chevron_right, size: 21, color: muted),
        ],
      ),
    ),
  );
}

class BookingFooter extends StatelessWidget {
  const BookingFooter({
    super.key,
    required this.label,
    required this.onTap,
    this.note,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final String? note;
  final bool busy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              note!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        FilledButton(
          onPressed: busy ? null : onTap,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ],
    ),
  );
}

class RouteMetrics extends StatelessWidget {
  const RouteMetrics(this.b, {super.key});
  final BookingController b;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 5,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 16),
          const SizedBox(width: 5),
          Text(
            '${b.tripRoute!.kilometers.toStringAsFixed(1).replaceAll('.', ',')} km',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 16),
          const SizedBox(width: 5),
          Text(
            formatDuration(b.tripRoute!.durationSeconds),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      Text(
        'Đến khoảng ${formatArrival(b.arrival!)}',
        style: const TextStyle(fontSize: 13, color: muted),
      ),
    ],
  );
}

class JourneyStops extends StatelessWidget {
  const JourneyStops(this.b, {super.key, this.editable = false});
  final BookingController b;
  final bool editable;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _stop(b.pickup!, false),
      const SizedBox(height: 17),
      _stop(b.destination!, true),
    ],
  );
  Widget _stop(Place place, bool destination) => Row(
    children: [
      StopDot(destination: destination),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              destination ? 'Điểm đến' : 'Điểm đón',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      if (editable)
        TextButton(
          onPressed: () => b.openSearch(pickupField: !destination),
          child: const Text('Sửa'),
        ),
    ],
  );
}
