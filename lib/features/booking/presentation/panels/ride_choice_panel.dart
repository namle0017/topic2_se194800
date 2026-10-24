import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';

import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../domain/ride_models.dart';
import '../components/booking_controls.dart';
import '../components/car_artwork.dart';

class RideChoicePanel extends StatelessWidget {
  const RideChoicePanel(this.b, {super.key});
  final BookingController b;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn chuyến đi',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa điểm đến',
                    onPressed: () => b.openSearch(),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              if (b.destination != null)
                Text(
                  b.destination!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: muted),
                ),
              const SizedBox(height: 10),
              if (b.loadingRoute)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Đang tìm tuyến đường…',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                )
              else if (b.tripRoute != null) ...[
                RouteMetrics(b),
                if (b.longDistance)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      b.specialTrip
                          ? 'Chuyến đường dài đặc biệt'
                          : 'Chuyến đường dài',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (b.specialTrip)
                  CheckboxListTile(
                    value: b.specialTripAccepted,
                    onChanged: (value) => b.acceptSpecialTrip(value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Mô phỏng chuyến đặc biệt',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Chuyến rất xa cần đơn vị vận tải xác nhận riêng. Giá tham khảo chưa gồm nghỉ, cầu đường và phụ phí.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 13),
                for (final ride in RideType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: _RideRow(
                      ride: ride,
                      selected: ride == b.selectedRide,
                      fare: ride.fareFor(b.tripRoute!),
                      onTap: () => b.chooseRide(ride),
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      const Icon(Icons.route_outlined, size: 30),
                      const SizedBox(height: 12),
                      Text(
                        b.error ?? 'Chưa có tuyến đường.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted),
                      ),
                      TextButton(
                        onPressed: b.loadRoute,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      if (b.tripRoute != null)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Giá tham khảo', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => showFareBreakdown(context, b),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  'Chi tiết giá',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      BookingFooter(
        label: b.quoteExpired ? 'Cập nhật giá' : 'Chọn ${b.selectedRide.label}',
        onTap: b.quoteExpired
            ? b.loadRoute
            : b.canConfirm
            ? b.confirmRide
            : null,
      ),
    ],
  );
}

class _RideRow extends StatelessWidget {
  const _RideRow({
    required this.ride,
    required this.selected,
    required this.fare,
    required this.onTap,
  });
  final RideType ride;
  final bool selected;
  final int fare;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${ride.label}, ${ride.seats} chỗ, ${formatVnd(fare)}',
    child: AnimatedContainer(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? ink : Colors.transparent,
          width: 2,
        ),
        color: selected ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: FittedBox(child: CarArtwork(ride: ride)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ride.seats} chỗ · ${ride.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 86,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatVnd(fare),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void showFareBreakdown(BuildContext context, BookingController b) {
  final ride = b.selectedRide;
  final route = b.tripRoute!;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => PointerInterceptor(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giá ước tính ${ride.label}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                for (final row in [
                  ...ride
                      .breakdown(route)
                      .lines
                      .map((l) => (l.label, formatVnd(l.amount.round()))),
                  (
                    'Làm tròn',
                    formatVnd(ride.breakdown(route).rounding.round()),
                  ),
                  ('Cầu đường, bến bãi, thời gian chờ', 'Chưa bao gồm'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.$1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(row.$2, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Tổng ước tính',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      formatVnd(ride.fareFor(route)),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Biểu phí tham khảo theo bậc khoảng cách, làm tròn lên 1.000 ₫. Không phải báo giá trực tiếp của hãng. '
                  'Chưa bao gồm cầu đường, bến bãi, thời gian chờ, nghỉ hoặc phụ phí. Thời gian lái xe ước tính chưa tính giao thông hiện tại.',
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
