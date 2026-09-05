import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Ukuran maksimum sisi terpanjang untuk foto yang diunggah.
///
/// Slot foto pada template hanya 472x472 px di kanvas 1333x2000, jadi 2000 px
/// masih jauh di atas kebutuhan cetak 4R 300 DPI (1200x1800).
const int _kMaxUploadSide = 2000;

/// Dijalankan di isolate terpisah oleh `compute()`.
/// Mengembalikan null bila foto sudah cukup kecil (pakai file aslinya saja).
class DownscaleResult {
  const DownscaleResult({
    required this.srcWidth,
    required this.srcHeight,
    this.bytes,
    this.outWidth,
    this.outHeight,
  });

  final int srcWidth;
  final int srcHeight;

  /// null = foto sudah cukup kecil, pakai file aslinya.
  final Uint8List? bytes;
  final int? outWidth;
  final int? outHeight;
}

DownscaleResult? _downscaleJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  if (decoded.width <= _kMaxUploadSide && decoded.height <= _kMaxUploadSide) {
    return DownscaleResult(srcWidth: decoded.width, srcHeight: decoded.height);
  }
  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: _kMaxUploadSide)
      : img.copyResize(decoded, height: _kMaxUploadSide);
  return DownscaleResult(
    srcWidth: decoded.width,
    srcHeight: decoded.height,
    bytes: img.encodeJpg(resized, quality: 90),
    outWidth: resized.width,
    outHeight: resized.height,
  );
}

/// PhotoUploadPrepService
///
/// Menyiapkan (memperkecil) foto untuk diunggah, JAUH sebelum halaman hasil
/// dibuka.
///
/// Kenapa perlu:
/// QR code baru bisa dirender setelah backend membalas `qr_token`, dan balasan
/// itu datang dari request `generate-result` yang mengunggah seluruh foto.
/// Sejak shutter PTP aktif tiap foto berukuran 6000x4000 (8-15 MB), sehingga
/// memperkecilnya saja sudah memakan beberapa detik — dan dulu itu dikerjakan
/// satu per satu, tepat saat halaman hasil terbuka, di jalur kritis.
///
/// Sekarang pekerjaan itu dimulai segera setelah tiap jepretan, selagi tamu
/// masih meninjau foto atau bersiap untuk pose berikutnya. Saat halaman hasil
/// terbuka, byte-nya biasanya sudah siap dan upload langsung jalan.
class PhotoUploadPrepService {
  PhotoUploadPrepService._();
  static final PhotoUploadPrepService instance = PhotoUploadPrepService._();

  /// Pekerjaan per path — dipakai ulang supaya satu file tidak diproses dua kali.
  final Map<String, Future<Uint8List?>> _jobs = {};

  /// Mulai menyiapkan sebuah foto tanpa menunggu selesai.
  /// Panggil ini tepat setelah foto berhasil dijepret.
  void warm(String path) {
    _jobs.putIfAbsent(path, () => _prepare(path));
  }

  /// Ambil hasilnya. Bila `warm()` sudah dipanggil lebih dulu, ini biasanya
  /// langsung selesai. Bila belum, pekerjaannya dimulai sekarang.
  Future<Uint8List?> bytesFor(String path) {
    return _jobs.putIfAbsent(path, () => _prepare(path));
  }

  /// Siapkan banyak foto sekaligus — PARALEL, bukan berurutan.
  Future<List<Uint8List?>> bytesForAll(List<String> paths) {
    return Future.wait(paths.map(bytesFor));
  }

  Future<Uint8List?> _prepare(String path) async {
    final sw = Stopwatch()..start();
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final raw = await file.readAsBytes();
      final res = await compute(_downscaleJpeg, raw);
      final name = path.split(Platform.pathSeparator).last;

      if (res == null) {
        debugPrint('⚠️ [UploadPrep] $name: gagal decode, pakai file asli');
        return null;
      }

      final srcMp = (res.srcWidth * res.srcHeight) / 1000000;
      if (res.bytes == null) {
        debugPrint('🗜️ [UploadPrep] $name: ${res.srcWidth}x${res.srcHeight} '
            '(${srcMp.toStringAsFixed(1)} MP, '
            '${(raw.length / 1048576).toStringAsFixed(1)} MB) — sudah kecil, '
            'diunggah apa adanya (${sw.elapsedMilliseconds}ms)');
        return null;
      }

      debugPrint('🗜️ [UploadPrep] $name: '
          '${res.srcWidth}x${res.srcHeight} (${srcMp.toStringAsFixed(1)} MP, '
          '${(raw.length / 1048576).toStringAsFixed(1)} MB) → '
          '${res.outWidth}x${res.outHeight} '
          '(${(res.bytes!.length / 1048576).toStringAsFixed(2)} MB) '
          'dalam ${sw.elapsedMilliseconds}ms');
      return res.bytes;
    } catch (e) {
      debugPrint('⚠️ [UploadPrep] gagal menyiapkan $path: $e');
      return null;
    }
  }

  /// Bersihkan cache di akhir sesi agar memori tidak menumpuk.
  void clear() => _jobs.clear();
}
