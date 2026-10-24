import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'core/app_theme.dart';
import 'features/booking/presentation/booking_screen.dart';

void main() {
  // Android TextureView allows Flutter to composite our animated sheet and pin.
  // This SDK setting is ignored by the web and iOS implementations.
  MapLibreMap.useHybridComposition = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride · Bản đồ đặt xe',
      debugShowCheckedModeBanner: false,
      theme: rideTheme(),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFEDEDEB),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
      home: const BookingScreen(),
    );
  }
}
