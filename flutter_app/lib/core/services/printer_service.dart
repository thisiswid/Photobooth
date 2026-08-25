import 'dart:io' show Platform, Socket;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

/// Connection mode options
enum PrinterConnectionMode {
  usbOnly,
  wifiOnly,
  usbWifiAuto,
}

/// PrinterService — single entry point for all printing (silent kiosk mode).
///
/// SATU-SATUNYA jalur cetak: Android PrintManager (MethodChannel 'printPhoto' /
/// 'printPdf') → Epson Print Service di tablet. Jalur ini silent (tanpa dialog
/// sistem) dan me-raster dokumen ke ESC/P-R resmi Epson, sehingga foto & test
/// page tercetak sebagai gambar benar — BUKAN kode/angka acak. Berlaku untuk
/// printer USB maupun Wi-Fi (Epson Print Service menangani keduanya).
///
/// ⚠️ RAW USB bulk transfer (kirim JPEG/PDF bytes langsung ke endpoint USB)
/// DIHAPUS PERMANEN: Epson L8050 membaca byte mentah sebagai perintah ESC/P
/// dan mencetaknya sebagai karakter acak. USB Host API hanya dipakai untuk
/// deteksi / permission / status (UI settings), TIDAK untuk mengirim data print.
///
/// Garansi 1 aksi = 1 PrintJob = 1 lembar: setiap panggilan printPhotoBytes /
/// printTestPage mengirim tepat SATU job tanpa retry otomatis, dilindungi lock
/// `_isPrintingBusy` terhadap eksekusi bersamaan/ganda.
class PrinterService {
  PrinterService._();

  static const _storage = FlutterSecureStorage();
  static const _ipKey = 'printer_ip_address';
  static const _defaultIp = '192.168.1.11';
  static const _channel = MethodChannel('com.fakultaskopi.photobooth/printer');

  // Keys for persistent configurations
  static const _modeKey = 'printer_connection_mode';
  static const _paperSizeKey = 'printer_paper_size';
  static const _copiesKey = 'printer_copies';
  static const _qualityKey = 'printer_quality';
  static const _orientationKey = 'printer_orientation';
  static const _borderlessKey = 'printer_borderless';
  static const _autoPrintKey = 'printer_auto_print';
  static const _autoReconnectKey = 'printer_auto_reconnect';
  static const _retryCountKey = 'printer_retry_count';

  static String? _cachedIp;
  static bool _isPrintingBusy = false; // Lock guard agar tidak ada print bersamaan / ganda

  // ─── Configuration & Storage ──────────────────────────────────────────────

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

  static Future<PrinterConnectionMode> getConnectionMode() async {
    try {
      final val = await _storage.read(key: _modeKey);
      if (val == 'usb_only') return PrinterConnectionMode.usbOnly;
      if (val == 'wifi_only') return PrinterConnectionMode.wifiOnly;
    } catch (_) {}
    return PrinterConnectionMode.usbWifiAuto; // Default
  }

  static Future<void> setConnectionMode(PrinterConnectionMode mode) async {
    String val = 'usb_wifi_auto';
    if (mode == PrinterConnectionMode.usbOnly) val = 'usb_only';
    if (mode == PrinterConnectionMode.wifiOnly) val = 'wifi_only';
    await _storage.write(key: _modeKey, value: val);
  }

  static Future<String> getPaperSize() async => (await _storage.read(key: _paperSizeKey)) ?? '4x6';
  static Future<void> setPaperSize(String v) async => await _storage.write(key: _paperSizeKey, value: v);

  static Future<int> getCopies() async => int.tryParse(await _storage.read(key: _copiesKey) ?? '1') ?? 1;
  static Future<void> setCopies(int c) async => await _storage.write(key: _copiesKey, value: c.toString());

  static Future<String> getQuality() async => (await _storage.read(key: _qualityKey)) ?? 'High';
  static Future<void> setQuality(String q) async => await _storage.write(key: _qualityKey, value: q);

  static Future<String> getOrientation() async => (await _storage.read(key: _orientationKey)) ?? 'Auto';
  static Future<void> setOrientation(String o) async => await _storage.write(key: _orientationKey, value: o);

  static Future<bool> getBorderless() async => (await _storage.read(key: _borderlessKey)) != 'false';
  static Future<void> setBorderless(bool b) async => await _storage.write(key: _borderlessKey, value: b.toString());

  static Future<bool> getAutoPrint() async => (await _storage.read(key: _autoPrintKey)) != 'false';
  static Future<void> setAutoPrint(bool b) async => await _storage.write(key: _autoPrintKey, value: b.toString());

  static Future<bool> getAutoReconnect() async => (await _storage.read(key: _autoReconnectKey)) != 'false';
  static Future<void> setAutoReconnect(bool b) async => await _storage.write(key: _autoReconnectKey, value: b.toString());

  static Future<int> getRetryCount() async => int.tryParse(await _storage.read(key: _retryCountKey) ?? '3') ?? 3;
  static Future<void> setRetryCount(int r) async => await _storage.write(key: _retryCountKey, value: r.toString());

  // ─── USB Detection & Permissions ──────────────────────────────────────────

  static Future<Map<String, dynamic>> detectUsbPrinter() async {
    if (!Platform.isAndroid) {
      return {'isDetected': false, 'deviceName': null, 'hasPermission': false, 'status': 'unsupported_platform'};
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('detectUsbPrinter');
      return res ?? {'isDetected': false, 'deviceName': null, 'hasPermission': false, 'status': 'disconnected'};
    } catch (e) {
      debugPrint('USB detect channel error: $e');
      return {'isDetected': false, 'deviceName': null, 'hasPermission': false, 'status': 'error'};
    }
  }

  static Future<bool> requestUsbPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('requestUsbPermission');
      return success ?? false;
    } catch (e) {
      debugPrint('USB permission request error: $e');
      return false;
    }
  }

  /// Cek apakah Kiosk Auto-Print Accessibility Helper sudah aktif di Android
  static Future<bool> isAutoPrintServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isAutoPrintServiceEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Buka menu Accessibility Settings di tablet untuk mengaktifkan Auto-Print Helper
  static Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Connectivity check via Wi-Fi IP socket
  static Future<bool> isPrinterReachable({String? ip}) async {
    final targetIp = ip ?? await getIpAddress();
    for (final port in [9100, 631, 80]) {
      try {
        final socket = await Socket.connect(
          targetIp,
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        debugPrint('✅ Wi-Fi Printer reachable di $targetIp:$port');
        return true;
      } catch (_) {}
    }
    debugPrint('❌ Wi-Fi Printer tidak dapat dijangkau di $targetIp');
    return false;
  }

  static Future<Map<String, dynamic>> getPrinterStatus() async {
    final usbStatus = await detectUsbPrinter();
    final wifiIp = await getIpAddress();
    final wifiReachable = await isPrinterReachable(ip: wifiIp);
    final mode = await getConnectionMode();

    String activeConn = 'None';
    if (usbStatus['isDetected'] == true && usbStatus['hasPermission'] == true) {
      activeConn = 'USB';
    } else if (wifiReachable) {
      activeConn = 'Wi-Fi';
    }

    return {
      'mode': mode,
      'usbDetected': usbStatus['isDetected'] ?? false,
      'usbPermission': usbStatus['hasPermission'] ?? false,
      'usbName': usbStatus['deviceName'] ?? 'Epson L8050 USB',
      'wifiIp': wifiIp,
      'wifiReachable': wifiReachable,
      'activeConnection': activeConn,
    };
  }

  // ─── Print Engine: Android PrintManager (SATU-SATUNYA jalur print) ────────

  /// Kirim FOTO via Android PrintManager → Epson Print Service.
  /// Silent print; mendukung printer USB maupun Wi-Fi. Tepat 1 PrintJob.
  /// ⚠️ BUKAN raw USB bulk transfer — bytes diraster driver Epson, bukan
  /// dilempar mentah ke printer.
  static Future<bool> _printPhotoViaPrintManager({
    required Uint8List imageBytes,
    required String jobName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      debugPrint('🖨️ Mengirim foto via Android PrintManager (Epson Print Service)...');
      final success = await _channel.invokeMethod<bool>('printPhoto', {
        'imageBytes': imageBytes,
        'jobName': jobName,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('PrintManager photo print error: $e');
      return false;
    }
  }


  /// Kirim PDF (Test Page) via Android PrintManager → Epson Print Service.
  /// Silent print; mendukung printer USB maupun Wi-Fi. Tepat 1 PrintJob.
  static Future<bool> _printPdfViaPrintManager({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      debugPrint('🖨️ Mengirim PDF via Android PrintManager (Epson Print Service)...');
      final success = await _channel.invokeMethod<bool>('printPdf', {
        'pdfBytes': pdfBytes,
        'jobName': jobName,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('PrintManager PDF print error: $e');
      return false;
    }
  }

  // ─── Public Print Methods ─────────────────────────────────────────────────

  /// Entry point cetak foto. SATU panggilan = SATU PrintJob = SATU lembar.
  ///
  /// Flow: Android PrintManager → Epson Print Service → printer (USB/Wi-Fi).
  /// PrintActivity terbuka otomatis — user tap 1x untuk konfirmasi cetak.
  ///
  /// Tidak ada retry otomatis — retry manual = PrintJob baru (tetap 1 lembar
  /// per aksi).
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    // 🔒 Static Lock Guard — prevent concurrent / double prints
    if (_isPrintingBusy) {
      debugPrint('⚠️ PrinterService busy dengan proses cetak lain. Batalkan duplikat.');
      return const PrintJobResult(
        isSuccess: false,
        message: 'Proses cetak sedang berlangsung.',
      );
    }
    _isPrintingBusy = true;

    try {
      if (!Platform.isAndroid) {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Printing hanya didukung pada perangkat Android.',
        );
      }

      debugPrint('🖨️ Mengirim foto ke Epson L8050 (AutoPrintService Kiosk)...');
      final success = await _printPhotoViaPrintManager(
        imageBytes: imageBytes,
        jobName: jobName,
      );

      if (success) {
        return const PrintJobResult(
          isSuccess: true,
          message: 'Foto berhasil dikirim ke printer Epson L8050',
          printerName: 'Epson L8050',
          isDirect: true,
        );
      }

      debugPrint('❌ Print job gagal.');
      return const PrintJobResult(
        isSuccess: false,
        message:
            'Gagal mencetak foto. Pastikan Epson L8050 menyala dan terhubung.',
        printerName: 'Epson L8050',
      );
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal mencetak foto: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Error cetak: $e',
      );
    } finally {
      _isPrintingBusy = false;
    }
  }

  /// Test Print — SATU panggilan = SATU PrintJob = SATU lembar.
  /// Jalur sama dengan foto: PrintManager → Epson Print Service (PDF diraster
  /// driver Epson sehingga teks tercetak normal, bukan kode acak).
  static Future<PrintJobResult> printTestPage() async {
    if (_isPrintingBusy) {
      return const PrintJobResult(
        isSuccess: false,
        message: 'Proses cetak sedang berlangsung.',
      );
    }
    _isPrintingBusy = true;

    try {
      if (!Platform.isAndroid) {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Printing hanya didukung pada perangkat Android.',
        );
      }

      final pdfBytes = await compute(_buildTestPdf, 0);
      debugPrint('🖨️ Test PDF siap: ${pdfBytes.length} bytes — kirim via PrintManager');

      final success = await _printPdfViaPrintManager(
        pdfBytes: pdfBytes,
        jobName: 'Test_Page',
      );

      if (success) {
        return const PrintJobResult(
          isSuccess: true,
          message: 'Test page berhasil dikirim ke printer Epson L8050',
          printerName: 'Epson L8050',
          isDirect: true,
        );
      }

      return const PrintJobResult(
        isSuccess: false,
        message:
            'Test page gagal dikirim. Pastikan Epson L8050 menyala (USB/Wi-Fi) dan Epson Print Service aktif.',
        printerName: 'Epson L8050',
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
    } finally {
      _isPrintingBusy = false;
    }
  }
}

// ─── Isolate functions (top-level) ────────────────────────────────────────────

Future<Uint8List> _buildTestPdf(int _) async {
  final doc = pw.Document();
  const pageWidth = 4.0 * PdfPageFormat.inch;
  const pageHeight = 6.0 * PdfPageFormat.inch;
  const pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);

  // Warna tema photobooth
  const darkBrown = PdfColor.fromInt(0xFF2C1A0E);
  const cream = PdfColor.fromInt(0xFFF3E6D0);
  const gold = PdfColor.fromInt(0xFFD4A853);
  const lightGrey = PdfColor.fromInt(0xFFCCCCCC);

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Stack(
        children: [
          // Background cream
          pw.Container(
            width: pageWidth,
            height: pageHeight,
            color: cream,
          ),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // ── Header ──
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  decoration: const pw.BoxDecoration(
                    color: darkBrown,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'FAKULTAS KOPI',
                        style: pw.TextStyle(
                          color: gold,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'PHOTOBOOTH',
                        style: pw.TextStyle(
                          color: cream,
                          fontSize: 10,
                          letterSpacing: 3,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 14),

                // ── 3 slot foto placeholder ──
                pw.Column(
                  children: List.generate(3, (i) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Container(
                      width: double.infinity,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        border: pw.Border.all(color: darkBrown, width: 1),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Center(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'FOTO ${i + 1}',
                              style: pw.TextStyle(
                                color: darkBrown,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '[ slot foto ]',
                              style: pw.TextStyle(
                                color: const PdfColor.fromInt(0xFF888888),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                ),

                pw.SizedBox(height: 6),

                // ── Info test ──
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: gold, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '✓ HALAMAN UJI PRINTER',
                        style: pw.TextStyle(
                          color: darkBrown,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Printer  : Epson L8050',
                          style: const pw.TextStyle(color: darkBrown, fontSize: 8)),
                      pw.Text('Kertas   : 4 × 6 inch (10 × 15 cm)',
                          style: const pw.TextStyle(color: darkBrown, fontSize: 8)),
                      pw.Text('Jalur    : PrintManager → Epson Print Service',
                          style: const pw.TextStyle(color: darkBrown, fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Jika halaman ini tercetak dengan benar,\nprinter siap digunakan.',
                        style: const pw.TextStyle(color: darkBrown, fontSize: 8),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // ── Footer ──
                pw.Text(
                  'snaptech • test page',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF888888),
                    fontSize: 7,
                    letterSpacing: 1,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}


