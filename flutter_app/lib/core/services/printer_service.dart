import 'dart:io' show Platform, Socket;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const _marginHorizKey = 'printer_margin_horizontal';
  static const _marginVertKey = 'printer_margin_vertical';
  static const _marginUnitKey = 'printer_margin_unit';

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

  static Future<String> getQuality() async => (await _storage.read(key: _qualityKey)) ?? 'Standard';
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

  static Future<double> getMarginHorizontal() async => double.tryParse(await _storage.read(key: _marginHorizKey) ?? '0.0') ?? 0.0;
  static Future<void> setMarginHorizontal(double v) async => await _storage.write(key: _marginHorizKey, value: v.toString());

  static Future<double> getMarginVertical() async => double.tryParse(await _storage.read(key: _marginVertKey) ?? '0.0') ?? 0.0;
  static Future<void> setMarginVertical(double v) async => await _storage.write(key: _marginVertKey, value: v.toString());

  static Future<String> getMarginUnit() async => (await _storage.read(key: _marginUnitKey)) ?? 'mm';
  static Future<void> setMarginUnit(String u) async => await _storage.write(key: _marginUnitKey, value: u);

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

  static Future<bool> _printPhotoViaPrintManager({
    required Uint8List imageBytes,
    required String jobName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final borderless = await getBorderless();
      final quality = await getQuality();
      final marginHoriz = await getMarginHorizontal();
      final marginVert = await getMarginVertical();
      final marginUnit = await getMarginUnit();
      debugPrint('🖨️ Mengirim foto via Android PrintManager (borderless: $borderless, quality: $quality, margin: $marginHoriz x $marginVert $marginUnit)...');
      final success = await _channel.invokeMethod<bool>('printPhoto', {
        'imageBytes': imageBytes,
        'jobName': jobName,
        'borderless': borderless,
        'quality': quality,
        'marginHorizontal': marginHoriz,
        'marginVertical': marginVert,
        'marginUnit': marginUnit,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('PrintManager photo print error: $e');
      return false;
    }
  }

  static Future<bool> _printPdfViaPrintManager({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final borderless = await getBorderless();
      final quality = await getQuality();
      final marginHoriz = await getMarginHorizontal();
      final marginVert = await getMarginVertical();
      final marginUnit = await getMarginUnit();
      debugPrint('🖨️ Mengirim PDF via Android PrintManager (borderless: $borderless, quality: $quality, margin: $marginHoriz x $marginVert $marginUnit)...');
      final success = await _channel.invokeMethod<bool>('printPdf', {
        'pdfBytes': pdfBytes,
        'jobName': jobName,
        'borderless': borderless,
        'quality': quality,
        'marginHorizontal': marginHoriz,
        'marginVertical': marginVert,
        'marginUnit': marginUnit,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('PrintManager PDF print error: $e');
      return false;
    }
  }

  // ─── Public Print Methods ─────────────────────────────────────────────────

  /// Method tunggal untuk mengirim print job ke Epson L8050.
  /// ⚠️ HANYA memanggil MethodChannel ke Android PrintManager + Epson Print Service.
  /// TIDAK ADA socket / raw USB bulk transfer yang memutus driver Epson.
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    if (_isPrintingBusy) {
      debugPrint('⚠️ Warning: Print job ditolak karena sedang ada pencetakan berlangsung.');
      return const PrintJobResult(
        isSuccess: false,
        message: 'Printer sedang memproses cetakan lain. Harap tunggu.',
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

      final success = await _printPhotoViaPrintManager(
        imageBytes: imageBytes,
        jobName: jobName,
      );

      if (success) {
        return const PrintJobResult(
          isSuccess: true,
          message: 'Cetak foto berhasil dikirim ke printer Epson L8050',
          printerName: 'Epson L8050',
          isDirect: true,
        );
      }

      return const PrintJobResult(
        isSuccess: false,
        message: 'Gagal mengirim print job ke Epson Print Service.',
        printerName: 'Epson L8050',
      );
    } catch (e, stack) {
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal cetak foto: $e',
        stackTrace: stack,
      );
      return PrintJobResult(
        isSuccess: false,
        message: 'Error cetak foto: $e',
      );
    } finally {
      _isPrintingBusy = false;
    }
  }

  /// Membuka dialog / mencetak test page resmi ke Epson L8050 via PrintManager.
  static Future<PrintJobResult> printTestPage() async {
    if (_isPrintingBusy) {
      debugPrint('⚠️ Warning: Test print ditolak karena sedang ada pencetakan berlangsung.');
      return const PrintJobResult(
        isSuccess: false,
        message: 'Printer sedang memproses cetakan lain. Harap tunggu.',
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

      final paperSize = await getPaperSize();
      final borderless = await getBorderless();
      final quality = await getQuality();
      final marginHoriz = await getMarginHorizontal();
      final marginVert = await getMarginVertical();
      final marginUnit = await getMarginUnit();

      final pdfBytes = await compute(_buildTestPdf, {
        'paperSize': paperSize,
        'borderless': borderless,
        'quality': quality,
        'marginHorizontal': marginHoriz,
        'marginVertical': marginVert,
        'marginUnit': marginUnit,
      });
      debugPrint('🖨️ Test PDF siap: ${pdfBytes.length} bytes — raster ke PNG image untuk Photo pipeline');

      Uint8List? pngBytes;
      try {
        await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 300)) {
          pngBytes = await page.toPng();
          break;
        }
      } catch (e) {
        debugPrint('Raster PDF error: $e');
      }

      final success = pngBytes != null
          ? await _printPhotoViaPrintManager(
              imageBytes: pngBytes,
              jobName: 'Test_Page',
            )
          : await _printPdfViaPrintManager(
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

Future<Uint8List> _buildTestPdf(Map<String, dynamic> params) async {
  final paperSize = params['paperSize'] as String? ?? '4x6';
  final borderless = params['borderless'] as bool? ?? true;
  final quality = params['quality'] as String? ?? 'Standard';
  final marginHoriz = (params['marginHorizontal'] as num?)?.toDouble() ?? 0.0;
  final marginVert = (params['marginVertical'] as num?)?.toDouble() ?? 0.0;
  final marginUnit = params['marginUnit'] as String? ?? 'mm';

  final doc = pw.Document();

  final double pageWidth = (paperSize == '2x6') ? 2.0 * PdfPageFormat.inch : 4.0 * PdfPageFormat.inch;
  const double pageHeight = 6.0 * PdfPageFormat.inch;
  final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);

  const black = PdfColors.black;
  const grey = PdfColors.grey700;

  // Conversion: 1 mm = 2.83465 pt
  const double pt05mm = 0.5 * 2.83465; // ~1.417 pt
  const double pt1mm  = 1.0 * 2.83465; // ~2.835 pt
  const double pt2mm  = 2.0 * 2.83465; // ~5.669 pt
  const double pt5mm  = 5.0 * 2.83465; // ~14.173 pt

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Stack(
        children: [
          // ── Garis Outline 0.5 mm dari tepi ──
          pw.Positioned(
            left: pt05mm,
            top: pt05mm,
            right: pt05mm,
            bottom: pt05mm,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: black, width: 0.5),
              ),
            ),
          ),

          // ── Garis Outline 1.0 mm dari tepi (Kompensasi Bleed) ──
          pw.Positioned(
            left: pt1mm,
            top: pt1mm,
            right: pt1mm,
            bottom: pt1mm,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: black, width: 0.5),
              ),
            ),
          ),

          // ── Garis Outline 2 mm dari tepi ──
          pw.Positioned(
            left: pt2mm,
            top: pt2mm,
            right: pt2mm,
            bottom: pt2mm,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: black, width: 0.5),
              ),
            ),
          ),

          // ── Garis Outline 5 mm dari tepi ──
          pw.Positioned(
            left: pt5mm,
            top: pt5mm,
            right: pt5mm,
            bottom: pt5mm,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: black, width: 0.5),
              ),
            ),
          ),

          // ── Label Sudut Kiri Atas ──
          pw.Positioned(
            left: pt5mm + 4,
            top: pt5mm + 4,
            child: pw.Text(
              'Edge Lines: 0.5mm / 1mm / 2mm / 5mm',
              style: const pw.TextStyle(fontSize: 6, color: grey),
            ),
          ),

          // ── Konten Utama (Tengah Page - Hemat Tinta 100%) ──
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Container(
                width: pageWidth * 0.8,
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: black, width: 0.8),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'CUSTOM MARGIN TEST',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: black,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Horizontal: ${marginHoriz.toStringAsFixed(1)} $marginUnit',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: black,
                      ),
                    ),
                    pw.Text(
                      'Vertical: ${marginVert.toStringAsFixed(1)} $marginUnit',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: black,
                      ),
                    ),
                    pw.Text(
                      'Borderless: ${borderless ? "ON" : "OFF"}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: black,
                      ),
                    ),
                    pw.Text(
                      'Quality: ${quality.toUpperCase()}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Paper Size: $paperSize inch',
                      style: const pw.TextStyle(fontSize: 8, color: grey),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: grey, width: 0.5),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'PETUNJUK VERIFIKASI BORDERLESS:',
                            style: const pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: black),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '• Borderless ON (Comp 1.0mm): Garis 1.0mm menyentuh pinggir kertas fisik.',
                            style: const pw.TextStyle(fontSize: 6, color: black),
                          ),
                          pw.Text(
                            '• Borderless OFF (Comp 0.0mm): Garis terdorong marjin putih ~5mm.',
                            style: const pw.TextStyle(fontSize: 6, color: black),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'snaptech test page — ink saving outline only',
                      style: const pw.TextStyle(fontSize: 6, color: grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
