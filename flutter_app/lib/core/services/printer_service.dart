import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'error_logger.dart';

/// Result status of a print job
class PrintJobResult {
  final bool isSuccess;
  final String message;
  final String? printerName;
  final bool isDirect;

  const PrintJobResult({
    required this.isSuccess,
    required this.message,
    this.printerName,
    this.isDirect = false,
  });
}

/// PrinterService — Mengelola pencetakan hasil foto ke Printer Epson L8050
/// Menggunakan raster PDF 4R (4×6 inch borderless) agar printer mencetak gambar foto asli
/// (bukan kode biner / karakter teks acak).
class PrinterService {
  PrinterService._();

  static const _storage = FlutterSecureStorage();
  static const _ipKey = 'printer_ip_address';
  static const _defaultIp = '192.168.1.14';

  static String? _cachedIp;
  static Printer? _selectedPrinter;

  static Printer? get selectedPrinter => _selectedPrinter;

  static void setSelectedPrinter(Printer? printer) {
    _selectedPrinter = printer;
  }

  // ─── IP Management ───────────────────────────────────────────────────────

  static Future<String> getIpAddress() async {
    if (_cachedIp != null) return _cachedIp!;
    try {
      final stored = await _storage.read(key: _ipKey);
      _cachedIp = stored ?? _defaultIp;
    } catch (_) {
      _cachedIp = _defaultIp;
    }
    return _cachedIp!;
  }

  static Future<void> setIpAddress(String ip) async {
    _cachedIp = ip;
    try {
      await _storage.write(key: _ipKey, value: ip);
      debugPrint('🖨️ IP printer disimpan: $ip');
    } catch (e) {
      debugPrint('Warning: gagal simpan IP printer ke storage: $e');
    }
  }

  // ─── Printer Discovery ───────────────────────────────────────────────────

  /// Mendapatkan daftar semua printer yang terdeteksi di sistem / jaringan / USB
  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      final printers = await Printing.listPrinters();
      debugPrint('🖨️ Printer terdeteksi (${printers.length}):');
      for (final p in printers) {
        debugPrint(' - ${p.name} (url: ${p.url}, default: ${p.isDefault}, available: ${p.isAvailable})');
      }
      return printers;
    } catch (e, stack) {
      debugPrint('Info listPrinters: $e');
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal mendeteksi printer: $e',
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Mencari printer Epson L8050 — retry jika belum terdeteksi
  static Future<Printer?> findEpsonPrinter({int maxRetries = 2}) async {
    if (_selectedPrinter != null) {
      return _selectedPrinter;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final printers = await getAvailablePrinters();
        if (printers.isNotEmpty) {
          // 1. Cari printer dengan nama L8050
          final l8050 = printers.where(
            (p) => p.name.toLowerCase().contains('l8050'),
          );
          if (l8050.isNotEmpty) return l8050.first;

          // 2. Cari printer merk Epson apapun
          final epson = printers.where(
            (p) => p.name.toLowerCase().contains('epson'),
          );
          if (epson.isNotEmpty) return epson.first;

          // 3. Fallback ke printer default / yang tersedia
          final available = printers.where((p) => p.isAvailable);
          if (available.isNotEmpty) return available.first;

          return printers.first;
        }
      } catch (e) {
        debugPrint('Error finding Epson printer (attempt $attempt): $e');
      }

      if (attempt < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    return null;
  }

  // ─── Print Photo Bytes ───────────────────────────────────────────────────

  /// Mencetak gambar (Uint8List) ke ukuran kertas foto 4R (4×6 inch / 100×150 mm)
  /// Menggunakan format PDF High-Resolution agar Epson L8050 meraster foto asli
  /// persis 1 lembar tanpa karakter aneh.
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    try {
      debugPrint('🖨️ Menyiapkan dokumen PDF 4R foto (${imageBytes.length} bytes)...');

      final doc = pw.Document(version: PdfVersion.pdf_1_5);
      final image = pw.MemoryImage(imageBytes);

      // Ukuran 4R standard borderless (4 inch x 6 inch)
      const pageFormat = PdfPageFormat(
        4.0 * PdfPageFormat.inch,
        6.0 * PdfPageFormat.inch,
        marginAll: 0,
      );

      for (int i = 0; i < copies; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(
                image,
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        );
      }

      final targetPrinter = _selectedPrinter ?? await findEpsonPrinter();

      if (targetPrinter != null) {
        debugPrint('🖨️ Mengirim PDF langsung ke printer: ${targetPrinter.name}');
        final printed = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: jobName,
        );

        if (printed) {
          return PrintJobResult(
            isSuccess: true,
            message: 'Foto berhasil dikirim ke printer ${targetPrinter.name}',
            printerName: targetPrinter.name,
            isDirect: true,
          );
        } else {
          return PrintJobResult(
            isSuccess: false,
            message: 'Printer ${targetPrinter.name} menolak atau membatalkan job cetak.',
            printerName: targetPrinter.name,
          );
        }
      } else {
        // Jika printer belum terdaftar otomatis, buka print dialog sistem (hanya 1x)
        debugPrint('ℹ️ Membuka layout print dialog sistem untuk memilih Epson L8050...');
        final printed = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: jobName,
        );

        return PrintJobResult(
          isSuccess: printed,
          message: printed ? 'Foto berhasil dikirim ke printer' : 'Cetak dibatalkan',
        );
      }
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal mencetak foto: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Error cetak: $e',
      );
    }
  }

  // ─── Test Print ───────────────────────────────────────────────────────────

  /// Mencetak 1 lembar halaman kartu uji diagnostik 4R
  static Future<PrintJobResult> printTestPage() async {
    try {
      final doc = pw.Document();
      const pageFormat = PdfPageFormat(
        4.0 * PdfPageFormat.inch,
        6.0 * PdfPageFormat.inch,
        marginAll: 20,
      );

      final now = DateTime.now();
      final timeStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) => pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.brown900, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'FAKULTAS KOPI PHOTOBOOTH',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'HALAMAN UJI EPSON L8050 (4R PHOTO)',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.Divider(color: PdfColors.amber800),
                pw.SizedBox(height: 12),
                pw.Text(
                  'STATUS: PRINTER SIAP MENCETAK',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Waktu: $timeStr', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text('Format: 4R (4 x 6 inch) Borderless', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                  child: pw.Text(
                    'Uji coba cetak foto 1 lembar berhasil.',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.brown900),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final targetPrinter = _selectedPrinter ?? await findEpsonPrinter();

      if (targetPrinter != null) {
        final printed = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: 'Photobooth_Test_Print',
        );

        return PrintJobResult(
          isSuccess: printed,
          message: printed
              ? 'Halaman uji dikirim ke ${targetPrinter.name}'
              : 'Gagal mengirim halaman uji.',
          printerName: targetPrinter.name,
          isDirect: true,
        );
      } else {
        final printed = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: 'Photobooth_Test_Print',
        );

        return PrintJobResult(
          isSuccess: printed,
          message: printed ? 'Halaman uji berhasil dicetak' : 'Cetak dibatalkan',
        );
      }
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal menjalankan test print: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Error test print: $e',
      );
    }
  }

  // ─── Connectivity Check ───────────────────────────────────────────────────

  static Future<bool> isPrinterReachable({String? ip}) async {
    final target = await findEpsonPrinter();
    return target != null;
  }
}

