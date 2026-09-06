import 'package:flutter/animation.dart';

/// Gerak Sistem Kamar Gelap.
///
/// Mesin lama bergerak tegas dan langsung. Tidak ada yang memantul, tidak ada
/// yang melar melewati sasarannya. Seluruh aplikasi hanya punya EMPAT gerakan.
abstract final class AppMotion {
  /// Kilat putih penuh, sekali, saat jepret.
  static const Duration shutter = Duration(milliseconds: 40);

  /// Strip bergeser naik satu slot saat pose masuk.
  static const Duration paperFeed = Duration(milliseconds: 240);

  /// Pudar masuk saat ganti layar. Tanpa geser.
  static const Duration reveal = Duration(milliseconds: 120);

  /// Ketukan tombol — keadaan berubah seketika.
  static const Duration tap = Duration.zero;

  /// Satu-satunya kurva yang dipakai.
  static const Curve standard = Curves.easeOut;

  // ── DILARANG ─────────────────────────────────────────────────────────────
  //
  //   Curves.easeOutBack, elasticOut, bounceOut  -> melar melewati sasaran
  //   .animate(onPlay: (c) => c.repeat(...))     -> denyut berulang
  //   .fadeIn(delay: (i * 40).ms)                -> stagger per-item
  //   scale(begin: 1.25) pada angka hitung mundur
  //
  // Tiga dari empat ini sedang berjalan di Welcome dan Tutorial. Hitungan
  // mundur memotong keras per detik, seperti penghitung mekanis.
}
