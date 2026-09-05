import 'package:flutter/material.dart';

/// SnapTechBooth default color palette — Authentic Vintage Coffee & Heritage Stationery.
/// Warm aged cream, roasted espresso brown, antique brass gold, and vintage stamp accents.
abstract final class AppColors {
  // ── Primary Brand Palette (Vintage Coffeehouse) ───────────────────────────
  static const Color cream        = Color(0xFFF5EDE0); // Warm aged parchment
  static const Color paper        = Color(0xFFEADBC5); // Classic craft paper
  static const Color darkBrown    = Color(0xFF2E1A11); // Deep roasted espresso
  static const Color brown        = Color(0xFF5A3622); // Warm vintage coffee
  static const Color lightBrown   = Color(0xFFB58F63); // Roasted hazelnut / brass
  static const Color buttonBrown  = Color(0xFF422314); // Rich espresso button
  static const Color creamWhite   = Color(0xFFFFFDF8); // Clean vintage milk white
  static const Color gold         = Color(0xFFC9974C); // Antique gold / warm brass

  // ── Vintage Accent Tones ──────────────────────────────────────────────────
  static const Color vintageRust      = Color(0xFFA63D2F); // Vintage stamp red/rust
  static const Color vintageSage      = Color(0xFF58705B); // Antique sage green
  static const Color vintageSepia     = Color(0xFF704D36); // Classic sepia photo tone
  static const Color vintageNavy      = Color(0xFF1E2E3D); // Deep vintage blueprint
  static const Color antiqueBrass     = Color(0xFFD4AF37); // Bright antique brass

  // ── Legacy aliases (maintained for backwards compatibility) ───────────────
  static const Color primary            = darkBrown;
  static const Color coffeeBrown        = darkBrown;
  static const Color darkCoffee         = Color(0xFF201009);
  static const Color white              = Color(0xFFFFFFFF);
  static const Color goldAccent         = gold;
  static const Color parchment          = cream;
  static const Color parchmentLight     = creamWhite;
  static const Color parchmentDark      = paper;
  static const Color cardBg             = creamWhite;
  static const Color coffeeLight        = brown;
  static const Color warmBeige          = Color(0xFFEDE4D3);
  static const Color backgroundParchment = cream;
  static const Color backgroundDark     = darkBrown;
  static const Color backgroundMedium   = brown;
  static const Color backgroundLight    = cream;
  static const Color surfaceCard        = creamWhite;
  static const Color surfaceModal       = creamWhite;

  // ── Text Colors ───────────────────────────────────────────────────────────
  static const Color textPrimary    = darkBrown;
  static const Color textSecondary  = brown;
  static const Color textMuted      = Color(0xFF8C6D53);
  static const Color textOnDark     = creamWhite;
  static const Color textOnLight    = darkBrown;

  // ── Border Colors ─────────────────────────────────────────────────────────
  static const Color borderLight  = Color(0xFFDECFC0);
  static const Color borderWarm   = Color(0xFFD4C1AC);
  static const Color borderGold   = gold;
  static const Color borderCream  = Color(0xFFEADBCE);
  static const Color borderDark   = darkBrown;

  // ── Semantic Colors ───────────────────────────────────────────────────────
  static const Color success      = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color error        = Color(0xFFB72B2B);
  static const Color errorLight   = Color(0xFFE57373);
  static const Color warning      = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoLight    = Color(0xFF60A5FA);

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlayDark   = Color(0xCC000000);
  static const Color overlayMedium = Color(0x99000000);
  static const Color overlayLight  = Color(0x44000000);

  // ── Gradient stops ────────────────────────────────────────────────────────
  static const List<Color> coffeeGradient    = [darkCoffee, darkBrown, buttonBrown];
  static const List<Color> goldGradient      = [Color(0xFFA17430), gold, Color(0xFFE2C285)];
  static const List<Color> parchmentGradient = [creamWhite, cream, paper];
  static const List<Color> vintageCardGradient = [Color(0xFFFFFDF8), Color(0xFFF6EDE0)];
}
