import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const ink = Color(0xFF000000);
const muted = Color(0xFF686868);
const surface = Color(0xFFF3F3F3);
const line = Color(0xFFE8E8E8);

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    ui.PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;

ThemeData rideTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: const ColorScheme.light(
    primary: ink,
    secondary: ink,
    surface: Colors.white,
  ),
  fontFamily: 'Manrope',
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.9,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFE6E6E6),
      minimumSize: const Size(double.infinity, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: ink),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ink, width: 1.5),
    ),
    hintStyle: const TextStyle(color: muted, fontSize: 16),
  ),
);
