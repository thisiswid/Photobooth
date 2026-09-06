import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Skala tipografi Sistem Kamar Gelap.
///
/// Enam langkah, dan berhenti di situ:
///
///   44  nameplate / hero
///   31  judul halaman
///   22  subjudul
///   16  teks baca
///   14  teks kecil
///   12  label kapital
///
/// Tidak ada lagi 11.5sp, 13.5sp, 9.5sp, atau 8.5sp yang dipilih per widget.
/// Kalau sebuah teks tidak cocok dengan salah satu dari enam ini, ukurannya
/// bukan yang salah — perannya yang belum jelas.
///
/// Pembagian typeface:
///   AppFonts.display (slab)      -> judul, teks baca, angka besar
///   AppFonts.ui      (condensed) -> label kapital, tombol, angka tabular
abstract final class AppTextStyles {
  // ── Nameplate ────────────────────────────────────────────────────────────

  static TextStyle get displayLarge => AppFonts.display(
        fontSize: 44.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -0.5,
        height: 1.06,
      );

  static TextStyle get displayMedium => AppFonts.display(
        fontSize: 31.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.18,
      );

  static TextStyle get displaySmall => AppFonts.display(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.25,
      );

  // ── Judul ────────────────────────────────────────────────────────────────

  static TextStyle get headlineLarge => AppFonts.display(
        fontSize: 31.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.18,
      );

  static TextStyle get headlineMedium => AppFonts.display(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.25,
      );

  static TextStyle get headlineSmall => AppFonts.display(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.35,
      );

  // ── Judul kecil — condensed ──────────────────────────────────────────────

  static TextStyle get titleLarge => AppFonts.ui(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.04,
        height: 1.35,
      );

  static TextStyle get titleMedium => AppFonts.ui(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.04,
        height: 1.4,
      );

  static TextStyle get titleSmall => AppFonts.ui(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink70,
        letterSpacing: 0.06,
        height: 1.4,
      );

  // ── Teks baca — slab ─────────────────────────────────────────────────────

  static TextStyle get bodyLarge => AppFonts.display(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.6,
      );

  static TextStyle get bodyMedium => AppFonts.display(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.55,
      );

  static TextStyle get bodySmall => AppFonts.display(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.ink70,
        height: 1.5,
      );

  /// Keterangan di bawah sesuatu. Dipakai 20x di seluruh aplikasi.
  static TextStyle get caption => AppFonts.display(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.ink70,
        height: 1.5,
      );

  // ── Label kapital — condensed ────────────────────────────────────────────
  //
  // Kapital HANYA untuk label dan tombol. Tidak pernah untuk kalimat.

  static TextStyle get labelLarge => AppFonts.ui(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.13 * 14,
      );

  static TextStyle get labelMedium => AppFonts.ui(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink70,
        letterSpacing: 0.14 * 12,
      );

  static TextStyle get labelSmall => AppFonts.ui(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.ink40,
        letterSpacing: 0.16 * 12,
      );

  // ── Peran khusus ─────────────────────────────────────────────────────────

  /// Teks tombol. Kapital, condensed, berjarak.
  static TextStyle get buttonText => AppFonts.ui(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.paperBright,
        letterSpacing: 0.13 * 14,
      );

  /// Angka hitung mundur. Slab besar — penghitung studio, bukan angka aplikasi.
  ///
  /// Dipotong keras per detik. TANPA scale-bounce: angka yang
  /// membesar-mengecil membaca sebagai aplikasi, bukan mesin.
  static TextStyle get countdownNumber => AppFonts.display(
        fontSize: 96.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.light,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Harga sesi.
  static TextStyle get priceText => AppFonts.display(
        fontSize: 31.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Timer sesi. Tabular, jadi lebarnya tidak bergeser tiap detik.
  static TextStyle get timerText => AppFonts.ui(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.06 * 14,
      );

  static TextStyle get timerTextWarning => AppFonts.ui(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.inkOxide,
        letterSpacing: 0.06 * 14,
      );

  /// Kode sesi.
  static TextStyle get sessionCode => AppFonts.ui(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.18 * 22,
      );

  /// Label status tercetak — BERHASIL / GAGAL / MENCETAK.
  ///
  /// WAJIB menyertai setiap status. Warna spot milik tenant bisa saja merah,
  /// jadi warna tidak boleh jadi satu-satunya penanda.
  static TextStyle get stampLabel => AppFonts.ui(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.16 * 12,
      );
}
