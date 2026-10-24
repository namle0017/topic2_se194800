import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';
import '../../domain/ride_models.dart';
import '../components/booking_controls.dart';
import '../components/car_artwork.dart';

class ConfirmationPanel extends StatelessWidget {
  const ConfirmationPanel(this.b, {super.key});
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
                'Xác nhận chuyến đi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              JourneyStops(b, editable: true),
              const SizedBox(height: 13),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  CarArtwork(ride: b.selectedRide),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.selectedRide.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${formatDuration(b.tripRoute!.durationSeconds)} di chuyển',
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatVnd(b.fare!),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      BookingFooter(
        label: 'Đặt chuyến demo',
        onTap: b.quoteExpired ? b.loadRoute : b.bookDemo,
        note: 'Mô phỏng đặt xe. Không gọi tài xế, không thu tiền.',
      ),
    ],
  );
}

class TripPanel extends StatelessWidget {
  const TripPanel(this.b, {super.key});
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
                b.simulationRunning
                    ? 'Đang trên đường'
                    : 'Chuyến đi đã sẵn sàng',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 9),
              Text(b.destination!.name, style: const TextStyle(color: muted)),
              const SizedBox(height: 18),
              RouteMetrics(b),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: b.simulationProgress,
                  minHeight: 4,
                  color: ink,
                  backgroundColor: line,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Xe minh họa chạy theo tuyến thật trong 25 giây.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
      BookingFooter(
        label: b.simulationRunning ? 'Kết thúc mô phỏng' : 'Chạy mô phỏng',
        onTap: b.simulationRunning ? b.reset : b.startSimulation,
      ),
    ],
  );
}

class CompletePanel extends StatelessWidget {
  const CompletePanel(this.b, {super.key});
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
              const Icon(Icons.check_circle, size: 30),
              const SizedBox(height: 10),
              Text(
                'Bạn đã đến nơi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 7),
              Text(b.destination!.name, style: const TextStyle(color: muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(b.selectedRide.label),
                  const Spacer(),
                  Text(
                    formatVnd(b.fare!),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      BookingFooter(
        label: 'Chuyến đi mới',
        onTap: b.reset,
        note: 'Đã kết thúc mô phỏng. Không phát sinh thanh toán.',
      ),
    ],
  );
}
