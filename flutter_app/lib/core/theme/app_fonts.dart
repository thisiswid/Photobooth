import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Satu-satunya tempat typeface ditentukan di seluruh aplikasi.
///
/// Sistem Kamar Gelap memakai DUA typeface, tidak lebih:
///
///   display -> Bitter (slab serif)
///              Huruf iklan, tiket, dan poster abad ke-20. Dipakai untuk
///              judul, nameplate, angka besar, dan teks yang dibaca.
///
///   ui      -> Archivo Narrow (gothic condensed)
///              Huruf formulir dan label cetak. Dipakai untuk label kapital,
///              tombol, dan semua angka yang harus sejajar per kolom.
///
/// Sebelumnya ada EMPAT typeface yang dipanggil langsung dari 214 tempat
/// (Montserrat 149x, Cormorant Garamond 37x, Inter 23x, Playfair Display 5x),
/// sehingga mengganti huruf berarti menyunting 214 berkas. Sekarang cukup di
/// sini.
///
/// ── CATATAN PRODUKSI ────────────────────────────────────────────────────
/// `google_fonts` MENGUNDUH font saat runtime. Di kiosk kafe dengan wifi
/// tidak stabil, aplikasi akan tampil dengan huruf bawaan sistem dan seluruh
/// sistem tipografi ini hilang tanpa suara.
///
/// Setelah TTF dibundel ke `assets/fonts/` dan didaftarkan di pubspec.yaml,
/// ganti isi kedua fungsi di bawah dengan TextStyle biasa:
///
///   return TextStyle(fontFamily: 'Bitter',        ...);
///   return TextStyle(fontFamily: 'ArchivoNarrow', ...);
///
/// Itu satu-satunya perubahan yang diperlukan.
/// ────────────────────────────────────────────────────────────────────────
abstract final class AppFonts {
  /// Slab serif — judul, nameplate, angka besar, teks yang dibaca.
  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.bitter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      shadows: shadows,
      fontFeatures: fontFeatures,
    );
  }

  /// Gothic condensed — label kapital, tombol, angka tabular.
  ///
  /// Angka SELALU tabular di sini: timer, harga, hitungan pose, dan kode sesi
  /// tidak boleh bergeser lebarnya tiap detik.
  static TextStyle ui({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.archivoNarrow(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      shadows: shadows,
      fontFeatures: fontFeatures ?? const [FontFeature.tabularFigures()],
    );
  }
}
