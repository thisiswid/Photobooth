import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Dua material Sistem Kamar Gelap.
///
/// Setiap layar memilih SATU. Tidak ada material ketiga, dan tidak ada
/// gradient yang menyeberang di antara keduanya.
enum BoothMaterial {
  /// Layar tempat tamu MEMILIH — Tiket, Bayar, Pilih bingkai, Pilih filter.
  /// Terang adalah bawaan aplikasi ini.
  paper,

  /// Layar tempat GAMBAR jadi subjeknya — Sambutan, pengambilan, Hasil.
  bench,
}

/// Warna yang benar untuk material yang sedang dipakai.
///
/// Semua widget cangkang mengambil dari sini, jadi satu layar cukup
/// menyebut materialnya sekali dan seluruh isinya ikut menyesuaikan.
extension BoothMaterialPalette on BoothMaterial {
  bool get isDark => this == BoothMaterial.bench;

  /// Permukaan utama.
  Color get surface =>
      isDark ? AppColors.bench : AppColors.paper;

  /// Permukaan yang terangkat di atasnya — kartu, panel, kolom.
  Color get raised =>
      isDark ? AppColors.benchRaised : AppColors.paperBright;

  /// Cerukan di dalam permukaan. Menggantikan bayangan.
  Color get recess =>
      isDark ? AppColors.bench : AppColors.paperDeep;

  /// Teks utama.
  Color get onSurface =>
      isDark ? AppColors.light : AppColors.ink;

  /// Teks sekunder.
  Color get onSurfaceMuted =>
      isDark ? AppColors.light60 : AppColors.ink70;

  /// Teks paling redup — label kecil.
  Color get onSurfaceFaint =>
      isDark ? AppColors.light30 : AppColors.ink40;

  /// Garis rambut struktur.
  Color get rule =>
      isDark ? AppColors.benchLine : AppColors.ink15;

  /// Garis "terpilih".
  Color get ruleStrong =>
      isDark ? AppColors.light : AppColors.ink;

  /// Warna spot pada tingkat yang terbaca di material ini.
  Color get spot =>
      isDark ? AppColors.spotLit : AppColors.spot;
}
