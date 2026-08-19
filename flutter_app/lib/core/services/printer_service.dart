import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'error_logger.dart';

/// PrinterService untuk mengelola pencetakan hasil foto ke Printer Epson L8050
/// (melalui Wi-Fi / Android Print Service / Network).
class PrinterService {
  PrinterService._();

  /// Mendapatkan daftar semua printer yang terdeteksi di jaringan / sistem
  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal mengambil daftar printer: $e',
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Mencari printer Epson L8050 di jaringan Wi-Fi atau printer default
  static Future<Printer?> findEpsonPrinter() async {
    try {
      final printers = await getAvailablePrinters();
      if (printers.isEmpty) return null;

      // Prioritaskan L8050
      final l8050 = printers.where(
        (p) => p.name.toLowerCase().contains('l8050'),
      );
      if (l8050.isNotEmpty) return l8050.first;

      // Cari printer merk Epson apapun
      final epson = printers.where(
        (p) => p.name.toLowerCase().contains('epson'),
      );
      if (epson.isNotEmpty) return epson.first;

      // Fallback ke printer default / pertama
      return printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.first,
      );
    } catch (e) {
      debugPrint('Error finding Epson printer: $e');
      return null;
    }
  }

  /// Mencetak gambar dari byte buffer (Uint8List) ke ukuran kertas foto 4R (4 x 6 inch)
  static Future<bool> printPhotoBytes({
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
        debugPrint('🖨️ Mencetak langsung ke: ${targetPrinter.name}');
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: jobName,
        );
      } else {
        debugPrint('⚠️ Printer Epson tidak ditemukan secara langsung, membuka dialog cetak sistem');
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: jobName,
        );
      }
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal mencetak foto ke printer: $e',
        stackTrace: stack,
      );
      return false;
    }
  }
}
