import 'package:flutter/material.dart';

/// Fakultas Kopi brand color palette — Premium Vintage Coffee.
/// Warm cream, deep coffee brown, inspired by vintage printed stationery.
abstract final class AppColors {
  // ── Primary Brand Palette ─────────────────────────────────────────────────
  static const Color cream        = Color(0xFFF3E6D0);
  static const Color paper        = Color(0xFFE8D5B7);
  static const Color darkBrown    = Color(0xFF3B2112);
  static const Color brown        = Color(0xFF6B4528);
  static const Color lightBrown   = Color(0xFFB8956A);
  static const Color buttonBrown  = Color(0xFF4A2915);
  static const Color creamWhite   = Color(0xFFFFF8ED);

  // ── Legacy aliases (kept for existing code) ───────────────────────────────
  static const Color coffeeBrown        = darkBrown;
  static const Color darkCoffee         = Color(0xFF2B1209);
  static const Color white              = Color(0xFFFFFFFF);
  static const Color goldAccent         = lightBrown;
  static const Color parchment          = cream;
  static const Color parchmentLight     = creamWhite;
  static const Color parchmentDark      = paper;
  static const Color cardBg             = creamWhite;
  static const Color coffeeLight        = brown;
  static const Color warmBeige          = Color(0xFFE8DFC9);
  static const Color backgroundParchment = cream;
  static const Color backgroundDark     = darkBrown;
  static const Color backgroundMedium   = brown;
  static const Color backgroundLight    = cream;
  static const Color surfaceCard        = creamWhite;
  static const Color surfaceModal       = creamWhite;

  // ── Text Colors ───────────────────────────────────────────────────────────
  static const Color textPrimary    = darkBrown;
  static const Color textSecondary  = brown;
  static const Color textMuted      = lightBrown;
  static const Color textOnDark     = creamWhite;
  static const Color textOnLight    = darkBrown;

  // ── Border Colors ─────────────────────────────────────────────────────────
  static const Color borderLight  = Color(0xFFD9CEBC);
  static const Color borderWarm   = Color(0xFFD9CEBC);
  static const Color borderGold   = lightBrown;
  static const Color borderCream  = Color(0xFFE5DAC9);
  static const Color borderDark   = darkBrown;

  // ── Semantic Colors ───────────────────────────────────────────────────────
  static const Color success      = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color error        = Color(0xFFC62828);
  static const Color errorLight   = Color(0xFFEF5350);
  static const Color warning      = Color(0xFFF57F17);
  static const Color warningLight = Color(0xFFFFB300);
  static const Color info         = Color(0xFF01579B);
  static const Color infoLight    = Color(0xFF0288D1);

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlayDark   = Color(0xCC000000);
  static const Color overlayMedium = Color(0x99000000);
  static const Color overlayLight  = Color(0x44000000);

  // ── Gradient stops ────────────────────────────────────────────────────────
  static const List<Color> coffeeGradient  = [darkCoffee, coffeeBrown];
  static const List<Color> goldGradient    = [Color(0xFF9E7A3A), lightBrown, Color(0xFFD4B07A)];
  static const List<Color> parchmentGradient = [creamWhite, cream, paper];
}
