import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';
import '../components/booking_controls.dart';

class PinPanel extends StatelessWidget {
  const PinPanel(this.b, {super.key});
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
              Text(
                b.editingPickup ? 'Chọn điểm đón' : 'Chọn điểm đến',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Di chuyển bản đồ để đặt pin đúng vị trí.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (b.resolvingPin)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.location_on_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.pinAddress?.name ??
                          (b.resolvingPin
                              ? 'Đang tìm địa chỉ…'
                              : 'Vị trí dưới pin'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      BookingFooter(
        label: b.editingPickup ? 'Xác nhận điểm đón' : 'Xác nhận điểm đến',
        onTap: b.confirmPin,
        busy: b.locating,
      ),
    ],
  );
}
