import 'dart:io' show Socket;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
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

/// PrinterService — silent printing ke Epson L8050 via Epson Print Enabler.
///
/// Epson Print Enabler (plugin Android resmi dari Epson) memungkinkan
/// Printing.listPrinters() mendeteksi printer Epson via Wi-Fi.
/// Setelah printer network ditemukan, directPrintPdf() bisa silent tanpa dialog.
///
/// Prioritas pemilihan printer:
/// 1. Printer yang URL-nya mengandung IP address (network/Wi-Fi)
/// 2. Printer yang namanya mengandung "network", "wifi", "wi-fi", atau IP
/// 3. Printer Epson L8050 apapun (hindari USB jika bisa)
/// 4. Fallback ke printer pertama yang tersedia
class PrinterService {
  PrinterService._();

  static const _storage = FlutterSecureStorage();
  static const _ipKey = 'printer_ip_address';
  static const _defaultIp = '192.168.1.14';

  static Printer? _selectedPrinter;
  static String? _cachedIp;

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
    _selectedPrinter = null; // reset agar di-refresh
    try {
      await _storage.write(key: _ipKey, value: ip);
      debugPrint('🖨️ IP printer disimpan: $ip');
    } catch (e) {
      debugPrint('Warning: gagal simpan IP printer ke storage: $e');
    }
  }

  static Future<void> clearIpAddress() async {
    _cachedIp = null;
    _selectedPrinter = null;
    try {
      await _storage.delete(key: _ipKey);
    } catch (_) {}
  }

  // ─── Printer Discovery ────────────────────────────────────────────────────

  /// Ambil semua printer yang terdeteksi.
  /// Pada Android, listPrinters() tidak didukung oleh native OS, sehingga
  /// kita menggunakan konfigurasi IP terverifikasi ke Epson L8050.
  static Future<List<Printer>> getAvailablePrinters() async {
    final ip = await getIpAddress();
    final isReachable = await isPrinterReachable(ip: ip);

    List<Printer> systemPrinters = [];
    if (!kIsWeb && !defaultTargetPlatform.toString().contains('android')) {
      try {
        systemPrinters = await Printing.listPrinters();
      } catch (_) {}
    }

    final epsonPrinter = Printer(
      url: 'tcp://$ip:9100',
      name: 'Epson L8050 ($ip)',
      isAvailable: isReachable,
      isDefault: true,
    );

    return [epsonPrinter, ...systemPrinters];
  }

  /// Temukan printer Epson L8050 via IP / Network.
  static Future<Printer?> findNetworkPrinter({int maxRetries = 2}) async {
    if (_selectedPrinter != null) return _selectedPrinter;

    final ip = await getIpAddress();
    final reachable = await isPrinterReachable(ip: ip);

    final printer = Printer(
      url: 'tcp://$ip:9100',
      name: 'Epson L8050 ($ip)',
      isAvailable: reachable,
      isDefault: true,
    );

    _selectedPrinter = printer;
    return printer;
  }

  /// Printer aktif yang tersimpan
  static Printer? get selectedPrinter => _selectedPrinter;

  /// Set printer aktif secara manual (dari modal settings)
  static void setSelectedPrinter(Printer printer) {
    _selectedPrinter = printer;
    debugPrint('🖨️ Printer dipilih manual: ${printer.name} (${printer.url})');
  }

  // ─── Image → PDF Helper ───────────────────────────────────────────────────

  /// Convert image bytes ke PDF 4R (4×6 inch) di background isolate.
  static Future<Uint8List> _buildPhotoPdf(Uint8List imageBytes) async {
    return compute(_buildPdfInIsolate, imageBytes);
  }

  // ─── Public Print Methods ─────────────────────────────────────────────────

  /// Mencetak foto ke Epson L8050 via Epson Print Enabler (silent, tanpa dialog).
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    try {
      // Cari printer network
      final printer = await findNetworkPrinter();
      if (printer == null) {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Printer tidak ditemukan.\n'
              'Pastikan Epson Print Enabler terinstall dan printer menyala.',
        );
      }

      debugPrint('🖨️ Memproses foto untuk dicetak ke ${printer.name}...');

      // Build PDF di isolate (tidak blokir UI)
      final pdfBytes = await _buildPhotoPdf(imageBytes);

      debugPrint('🖨️ PDF siap: ${pdfBytes.length} bytes, mengirim ke ${printer.name}...');

      bool printed = false;
      try {
        printed = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdfBytes,
          name: jobName,
        );
      } catch (e) {
        debugPrint('directPrintPdf note: $e, falling back to layoutPdf...');
        printed = await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: jobName,
        );
      }

      if (printed) {
        return PrintJobResult(
          isSuccess: true,
          message: 'Foto berhasil dicetak ke ${printer.name}',
          printerName: printer.name,
          isDirect: true,
        );
      } else {
        ErrorLogger.instance.logHardwareError(
          message: 'Printer menolak job: ${printer.name}',
        );
        return PrintJobResult(
          isSuccess: false,
          message: 'Printer menolak job cetak.',
          printerName: printer.name,
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

  /// Cetak halaman uji — silent print via Epson Print Enabler.
  static Future<PrintJobResult> printTestPage() async {
    try {
      final printer = await findNetworkPrinter();
      if (printer == null) {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Printer tidak ditemukan. Pastikan printer menyala di jaringan yang sama.',
        );
      }

      final pdfBytes = await compute(_buildTestPdf, 0);

      bool printed = false;
      try {
        printed = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdfBytes,
          name: 'Test_Page',
        );
      } catch (e) {
        debugPrint('directPrintPdf test note: $e, falling back to layoutPdf...');
        printed = await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'Test_Page',
        );
      }

      return PrintJobResult(
        isSuccess: printed,
        message: printed
            ? 'Halaman uji dikirim ke ${printer.name}'
            : 'Gagal mengirim halaman uji ke ${printer.name}',
        printerName: printer.name,
        isDirect: true,
      );
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal test print: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Error test print: $e',
      );
    }
  }

  // ─── Connectivity Check ───────────────────────────────────────────────────

  /// Cek apakah printer network dapat dijangkau.
  static Future<bool> isPrinterReachable({String? ip}) async {
    final targetIp = ip ?? await getIpAddress();
    try {
      final socket = await Socket.connect(
        targetIp,
        9100,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      debugPrint('✅ Printer reachable di $targetIp:9100');
      return true;
    } catch (e) {
      debugPrint('❌ Printer tidak dapat dijangkau di $targetIp — $e');
      return false;
    }
  }
}

// ─── Isolate functions (top-level, no class state) ────────────────────────────

/// Build PDF 4R dari image bytes — dijalankan di isolate terpisah.
Future<Uint8List> _buildPdfInIsolate(Uint8List imageBytes) async {
  // Decode & resize ke 4R landscape (1800×1200)
  final decoded = img.decodeImage(imageBytes);
  Uint8List jpegBytes;

  if (decoded != null) {
    img.Image oriented = decoded.height > decoded.width
        ? img.copyRotate(decoded, angle: 90)
        : decoded;

    final resized = img.copyResize(
      oriented,
      width: 1800,
      height: 1200,
      interpolation: img.Interpolation.linear,
    );
    jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 92));
  } else {
    jpegBytes = imageBytes;
  }

  // Build PDF 4R (4×6 inch)
  final doc = pw.Document();
  const pageFormat = PdfPageFormat(
    4.0 * PdfPageFormat.inch,
    6.0 * PdfPageFormat.inch,
    marginAll: 0,
  );

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (pw.Context context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Image(
          pw.MemoryImage(jpegBytes),
          fit: pw.BoxFit.cover,
        ),
      ),
    ),
  );

  return doc.save();
}

/// Build test PDF sederhana — dijalankan di isolate.
Future<Uint8List> _buildTestPdf(int _) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'HALAMAN UJI PRINTER',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Epson L8050 — Fakultas Kopi Photobooth'),
            pw.Text('Jika halaman ini tercetak, printer terhubung dengan benar.'),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
