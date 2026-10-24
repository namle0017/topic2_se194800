import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/ride_models.dart';

class CarArtwork extends StatelessWidget {
  const CarArtwork({super.key, this.ride = RideType.standard});
  final RideType ride;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    height: 48,
    child: CustomPaint(painter: _CarPainter(ride)),
  );
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.ride);
  final RideType ride;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 60);
    canvas.drawOval(
      const Rect.fromLTWH(5, 44, 91, 10),
      Paint()..color = Colors.black.withValues(alpha: .08),
    );
    final suv = ride == RideType.xl;
    final body = Path()
      ..moveTo(5, 40)
      ..lineTo(7, 31)
      ..lineTo(22, 27)
      ..lineTo(33, suv ? 13 : 19)
      ..quadraticBezierTo(36, suv ? 11 : 16, 42, suv ? 11 : 16)
      ..lineTo(67, suv ? 11 : 16)
      ..quadraticBezierTo(71, 17, 79, 27)
      ..lineTo(91, 30)
      ..quadraticBezierTo(97, 32, 97, 41)
      ..lineTo(95, 46)
      ..lineTo(7, 46)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 17),
          const Offset(0, 47),
          ride == RideType.comfort
              ? [const Color(0xFF676C70), const Color(0xFF282C2F)]
              : [const Color(0xFFE8EBED), const Color(0xFF9BA2A7)],
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF80888E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final window = Path()
      ..moveTo(27, 27)
      ..lineTo(38, suv ? 15 : 20)
      ..lineTo(65, suv ? 15 : 20)
      ..lineTo(73, 27)
      ..close();
    canvas.drawPath(
      window,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(38, 15),
          const Offset(70, 29),
          [const Color(0xFF5E707A), const Color(0xFF26343C)],
        ),
    );
    canvas.drawLine(
      const Offset(51, 17),
      const Offset(51, 43),
      Paint()
        ..color = const Color(0xFF92999D)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(72, 28),
      const Offset(75, 42),
      Paint()
        ..color = const Color(0xFF92999D)
        ..strokeWidth = .6,
    );
    canvas.drawLine(
      const Offset(11, 38),
      const Offset(90, 38),
      Paint()
        ..color = Colors.white.withValues(alpha: .45)
        ..strokeWidth = .8,
    );
    for (final x in [24.0, 79.0]) {
      canvas.drawCircle(
        Offset(x, 44),
        8,
        Paint()..color = const Color(0xFF25282A),
      );
      canvas.drawCircle(
        Offset(x, 44),
        4.7,
        Paint()..color = const Color(0xFFA8AFB4),
      );
      canvas.drawCircle(
        Offset(x, 44),
        2,
        Paint()..color = const Color(0xFF555D62),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(90, 31, 5, 4),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFFFCE1),
    );
    canvas.drawRect(
      const Rect.fromLTWH(7, 31, 3, 4),
      Paint()..color = const Color(0xFFA65151),
    );
    canvas.drawLine(
      const Offset(56, 32),
      const Offset(63, 32),
      Paint()
        ..color = const Color(0xFF6A7277)
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(_CarPainter oldDelegate) => oldDelegate.ride != ride;
}

Future<ui.Image> createMapIcon(String kind) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (kind == 'car') {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 4, 24, 44),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      body.shift(const Offset(2, 2)),
      Paint()..color = Colors.black.withValues(alpha: .14),
    );
    for (final x in [9.0, 34.0]) {
      for (final y in [12.0, 34.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 5, 8),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF363B3E),
        );
      }
    }
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFDFDFD));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF879198)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 15, 18, 21),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF394950),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 20, 16, 11),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFE4E8E9),
    );
  } else if (kind == 'pickup') {
    canvas.drawCircle(const Offset(24, 24), 15, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(24, 24), 11, Paint()..color = Colors.black);
    canvas.drawCircle(const Offset(24, 24), 5, Paint()..color = Colors.white);
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 9, 30, 30),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(13, 13, 22, 22),
      Paint()..color = Colors.black,
    );
    canvas.drawRect(
      const Rect.fromLTWH(20, 20, 8, 8),
      Paint()..color = Colors.white,
    );
  }
  return recorder.endRecording().toImage(48, 56);
}
