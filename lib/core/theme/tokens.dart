import 'package:flutter/material.dart';

/// Design tokens from UI spec §5. Single source of truth — no hard-coded
/// colors/sizes in widgets; always read from here via Theme / AppTokens.
abstract final class AppTokens {
  // Brand
  static const primaryLight = Color(0xFF5B5BD6);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const backgroundLight = Color(0xFFF6F6FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF14141F);
  static const textSecondaryLight = Color(0xFF6B6B80);
  static const dividerLight = Color(0xFFE6E6F0);

  static const primaryDark = Color(0xFF8E8EF5);
  static const onPrimaryDark = Color(0xFF14143A);
  static const backgroundDark = Color(0xFF0C0C14);
  static const surfaceDark = Color(0xFF16161F);
  static const textPrimaryDark = Color(0xFFF2F2F8);
  static const textSecondaryDark = Color(0xFFA0A0B8);
  static const dividerDark = Color(0xFF262633);

  static const dangerLight = Color(0xFFE5484D);
  static const dangerDark = Color(0xFFFF6B70);
  static const warningLight = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFFBBF24);

  // Meal tags (same in light + dark). Always show text label, never color alone.
  static const breakfast = Color(0xFFF59E0B);
  static const lunch = Color(0xFFEF6C4D);
  static const snack = Color(0xFFEC4899);
  static const dinner = Color(0xFF0EA5E9);

  // Shape / spacing
  static const spacing = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0];
  static const radiusCard = 16.0;
  static const radiusSheet = 24.0;
  static const minTapTarget = 48.0;

  // Type scale (Inter bundled via pubspec; do not fetch over network)
  static const title = TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700);
  static const heading = TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400);
}
