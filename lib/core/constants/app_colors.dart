import 'package:flutter/material.dart';

/// MobiTrail Brand Color Palette
/// Primary: Orange-Red (#E8381A) derived from the MobiTrail logo
class AppColors {
  AppColors._();

  // ─── BRAND COLORS ────────────────────────────────────────────────────────────
  /// Primary orange-red from MobiTrail logo
  static const Color primary = Color(0xFFE8381A);
  static const Color primaryLight = Color(0xFFFAEAE6);
  static const Color primaryDark = Color(0xFFB52E14);
  static const Color primaryMid = Color(0xFFEF5733);

  /// Secondary – near-black from logo text
  static const Color secondary = Color(0xFF1C1C1C);
  static const Color secondaryLight = Color(0xFF3A3A3A);

  // ─── NEUTRAL / GREYSCALE ─────────────────────────────────────────────────────
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ─── SEMANTIC COLORS ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF15803D);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // ─── LIGHT THEME SURFACES ────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color inputFillLight = Color(0xFFF5F5F5);
  static const Color borderLight = Color(0xFFE8E8E8);

  // ─── DARK THEME SURFACES ─────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceDark2 = Color(0xFF252525);
  static const Color inputFillDark = Color(0xFF222222);
  static const Color borderDark = Color(0xFF2E2E2E);

  // ─── TEXT COLORS ─────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF111111);
  static const Color textSubtitle = Color(0xFF555555);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color textLight = Color(0xFFF1F1F1);
  static const Color textMutedDark = Color(0xFF8A8A8A);

  // ─── OVERLAY / GRADIENT ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8381A), Color(0xFFB52E14)],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
  );
}
