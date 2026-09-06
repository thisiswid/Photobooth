/// Geometri Sistem Kamar Gelap.
///
/// Nilai mentah — pemanggil yang menerapkan `.r` / `.w` / `.h` dari ScreenUtil.
abstract final class AppGeometry {
  // ── Radius ───────────────────────────────────────────────────────────────
  //
  // Empat nilai, masing-masing punya arti. Sebelumnya ada dua belas
  // (6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 30, 999) yang dipilih per widget.
  //
  // Kalau sebuah elemen tidak cocok dengan salah satu dari empat ini,
  // elemennya yang salah — bukan skalanya yang kurang.

  /// Cetak. Lembar, strip foto, panel, tabel.
  static const double radiusPrint = 0;

  /// Sel foto di dalam strip.
  static const double radiusCell = 2;

  /// Kartu dan tombol.
  static const double radiusCard = 4;

  /// Pil timer sesi. HANYA itu.
  static const double radiusPill = 999;

  // ── Garis ────────────────────────────────────────────────────────────────
  //
  // Tidak ada lagi 1.2 / 1.4 / 1.5 / 1.8 / 2.5 yang dikarang per widget.

  /// Struktur — dipakai dengan tinta 40.
  static const double hairline = 1;

  /// "Terpilih" — dipakai dengan tinta 100.
  static const double ruleSelected = 2;

  // ── Spasi ────────────────────────────────────────────────────────────────
  // Kelipatan 8, dengan satu langkah setengah di bawahnya.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  // ── Target sentuh ────────────────────────────────────────────────────────
  //
  // Ditegakkan, bukan sekadar dideklarasikan. Konstanta lama
  // `AppConstants.minTouchTarget = 64` tidak pernah dipakai di satu tempat
  // pun, dan banyak tombol berakhir setinggi 40-46.
  static const double touchTarget = 64;

  // ── Bayangan ─────────────────────────────────────────────────────────────
  //
  // Nol bayangan di mana pun, dengan SATU pengecualian: strip foto, karena
  // dia memang benda yang tergeletak di meja. Kertas di atas kertas tidak
  // melayang. Kedalaman datang dari garis dan cerukan, bukan dari blur.
  static const double stripShadowBlur = 26;
  static const double stripShadowY = 10;
}
