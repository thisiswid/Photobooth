import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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

/// PrinterService untuk mengelola pencetakan hasil foto ke Printer Epson L8050
/// (melalui Wi-Fi / Android Print Service / Network).
class PrinterService {
  PrinterService._();

  /// Mendapatkan daftar semua printer yang terdeteksi di jaringan / sistem
  static Future<List<Printer>> getAvailablePrinters() async {
    // Pada Android, Printing.listPrinters tidak didukung oleh native OS tanpa print dialog
    if (!kIsWeb && Platform.isAndroid) {
      return [];
    }

    try {
      final printers = await Printing.listPrinters();
      debugPrint('🖨️ Printer terdeteksi (${printers.length}):');
      for (final p in printers) {
        debugPrint(' - ${p.name} (url: ${p.url}, default: ${p.isDefault}, available: ${p.isAvailable})');
      }
      return printers;
    } catch (e, stack) {
      debugPrint('Info listPrinters: $e');
      return [];
    }
  }

  /// Mencari printer Epson L8050 — retry 3x dengan jeda 1 detik
  /// (USB enumerate di Android kadang butuh beberapa momen setelah app buka)
  static Future<Printer?> findEpsonPrinter({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final printers = await getAvailablePrinters();
        if (printers.isNotEmpty) {
          // 1. Prioritaskan L8050
          final l8050 = printers.where(
            (p) => p.name.toLowerCase().contains('l8050'),
          );
          if (l8050.isNotEmpty) return l8050.first;

          // 2. Cari printer merk Epson apapun
          final epson = printers.where(
            (p) => p.name.toLowerCase().contains('epson'),
          );
          if (epson.isNotEmpty) return epson.first;

          // 3. Fallback ke printer default / pertama yang tersedia
          final available = printers.where((p) => p.isAvailable);
          if (available.isNotEmpty) return available.first;

          return printers.first;
        }
      } catch (e) {
        debugPrint('Error finding Epson printer (attempt $attempt): $e');
      }

      if (attempt < maxRetries) {
        debugPrint('⏳ Printer belum terdeteksi, coba lagi dalam 1 detik... ($attempt/$maxRetries)');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('❌ Printer tidak ditemukan setelah $maxRetries percobaan.');
    return null;
  }

  /// Mencetak gambar dari byte buffer (Uint8List) ke ukuran kertas foto 4R (4 x 6 inch)
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    try {
      final doc = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      // Ukuran 4R standard (4 inch x 6 inch)
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

      final targetPrinter = await findEpsonPrinter();
      if (targetPrinter != null) {
        debugPrint('🖨️ Mengirim job cetak langsung ke: ${targetPrinter.name}');
        final printed = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: jobName,
        );

        if (printed) {
          return PrintJobResult(
            isSuccess: true,
            message: 'Berhasil dikirim ke printer ${targetPrinter.name}',
            printerName: targetPrinter.name,
            isDirect: true,
          );
        } else {
          ErrorLogger.instance.logHardwareError(
            message: 'Printer ${targetPrinter.name} menolak atau membatalkan job cetak.',
          );
          return PrintJobResult(
            isSuccess: false,
            message: 'Gagal mencetak: Printer tidak merespons job.',
            printerName: targetPrinter.name,
          );
        }
      } else {
        debugPrint('❌ Printer tidak ditemukan — cetak dibatalkan (tidak buka dialog).');
        return const PrintJobResult(
          isSuccess: false,
          message: 'Printer tidak terdeteksi. Pastikan printer menyala dan terhubung via USB.',
        );
      }
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal memproses dokumen cetak: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Terjadi kesalahan sistem print: $e',
      );
    }
  }

  static Printer? _selectedPrinter;

  static Printer? get selectedPrinter => _selectedPrinter;

  static void setSelectedPrinter(Printer? printer) {
    _selectedPrinter = printer;
  }

  /// Mencetak lembar uji coba (Test Print) untuk memvalidasi fungsi printer
  static Future<PrintJobResult> printTestPage() async {
    try {
      final doc = pw.Document();
      const pageFormat = PdfPageFormat(
        4.0 * PdfPageFormat.inch,
        6.0 * PdfPageFormat.inch,
        marginAll: 20,
      );

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
                  'HARDWARE DIAGNOSTIC TEST',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(color: PdfColors.amber800),
                pw.SizedBox(height: 12),
                pw.Text('Status: PRINTER CONNECTED & READY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Timestamp: ${DateTime.now().toIso8601String()}'),
                pw.SizedBox(height: 6),
                pw.Text('Paper Size: 4R (4 x 6 inch)'),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                  child: pw.Text('Hardware check passed successfully.', style: const pw.TextStyle(fontSize: 10)),
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
          name: 'Hardware_Test_Print',
        );

        return PrintJobResult(
          isSuccess: printed,
          message: printed
              ? 'Test print berhasil dikirim ke ${targetPrinter.name}'
              : 'Gagal mengirim test print.',
          printerName: targetPrinter.name,
          isDirect: true,
        );
      } else {
        // Fallback: buka system print dialog jika direct print gagal mendeteksi printer otomatis
        final printed = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: 'Hardware_Test_Print',
        );
        return PrintJobResult(
          isSuccess: printed,
          message: printed ? 'Halaman tes dikirim via System Dialog' : 'Cetak dibatalkan',
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
}

