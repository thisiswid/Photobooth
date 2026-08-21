import 'dart:io' show Platform, Socket;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
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

/// PrinterService — auto-printing ke Epson L8050 via native Android PrintManager.
///
/// Urutan strategi cetak:
/// 1. Native Android PrintManager (via MethodChannel) — menggunakan Epson Print Enabler
/// 2. IPP over HTTP — jika IPP aktif di printer
/// 3. Printing plugin fallback
class PrinterService {
  PrinterService._();

  static const _storage = FlutterSecureStorage();
  static const _ipKey = 'printer_ip_address';
  static const _defaultIp = '192.168.1.14';
  static const _channel = MethodChannel('com.fakultaskopi.photobooth/printer');

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
    try {
      await _storage.write(key: _ipKey, value: ip);
      debugPrint('🖨️ IP printer disimpan: $ip');
    } catch (e) {
      debugPrint('Warning: gagal simpan IP printer ke storage: $e');
    }
  }

  static Future<void> clearIpAddress() async {
    _cachedIp = null;
    try {
      await _storage.delete(key: _ipKey);
    } catch (_) {}
  }

  // ─── Connectivity Check ───────────────────────────────────────────────────

  /// Cek apakah printer dapat dijangkau di port manapun.
  static Future<bool> isPrinterReachable({String? ip}) async {
    final targetIp = ip ?? await getIpAddress();
    for (final port in [9100, 631, 80]) {
      try {
        final socket = await Socket.connect(
          targetIp,
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
        debugPrint('✅ Printer reachable di $targetIp:$port');
        return true;
      } catch (_) {}
    }
    debugPrint('❌ Printer tidak dapat dijangkau di $targetIp');
    return false;
  }

  // ─── Image → PDF Helper ───────────────────────────────────────────────────

  /// Convert image bytes ke PDF 4×6 inch di background isolate.
  static Future<Uint8List> _buildPhotoPdf(Uint8List imageBytes) async {
    return compute(_buildPdfInIsolate, imageBytes);
  }

  // ─── Native Android Print ─────────────────────────────────────────────────

  /// Cetak foto via native Android PrintManager (MethodChannel).
  /// Menggunakan Epson Print Enabler yang sudah terpasang dan aktif.
  static Future<bool> _printViaNativeChannel({
    required Uint8List imageBytes,
    required String jobName,
  }) async {
    try {
      debugPrint('🖨️ Mengirim ke native Android PrintManager...');
      final success = await _channel.invokeMethod<bool>('printPhoto', {
        'imageBytes': imageBytes,
        'jobName': jobName,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Native print channel error: $e');
      return false;
    }
  }

  /// Cetak PDF via native Android PrintManager (MethodChannel).
  static Future<bool> _printPdfViaNativeChannel({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    try {
      debugPrint('🖨️ Mengirim PDF ke native Android PrintManager...');
      final success = await _channel.invokeMethod<bool>('printPdf', {
        'pdfBytes': pdfBytes,
        'jobName': jobName,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Native PDF print channel error: $e');
      return false;
    }
  }

  // ─── IPP Print via HTTP ───────────────────────────────────────────────────

  /// Coba kirim PDF via IPP ke beberapa endpoint.
  static Future<bool> _trySendIpp({
    required String printerIp,
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    final endpoints = [
      'http://$printerIp:631/ipp/print',
      'http://$printerIp:631/ipp',
      'http://$printerIp:80/EPSON_IPP_Printer',
      'http://$printerIp:80/ipp/print',
    ];

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        try {
          final socket = await Socket.connect(uri.host, uri.port,
              timeout: const Duration(seconds: 2));
          socket.destroy();
        } catch (_) {
          continue;
        }

        debugPrint('🖨️ Mencoba IPP: $endpoint');
        final success = await _sendIppToEndpoint(
          endpoint: endpoint,
          pdfBytes: pdfBytes,
          jobName: jobName,
        );
        if (success) {
          debugPrint('✅ IPP berhasil via $endpoint');
          return true;
        }
      } catch (e) {
        debugPrint('   IPP gagal di $endpoint: $e');
      }
    }
    return false;
  }

  static Future<bool> _sendIppToEndpoint({
    required String endpoint,
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    final uri = Uri.parse(endpoint);
    final ippUri = endpoint
        .replaceFirst('http://', 'ipp://')
        .replaceFirst('https://', 'ipps://');

    final ippHeader = _buildIppPrintJobRequest(
      jobName: jobName,
      printerUri: ippUri,
    );

    final body = Uint8List(ippHeader.length + pdfBytes.length);
    body.setRange(0, ippHeader.length, ippHeader);
    body.setRange(ippHeader.length, body.length, pdfBytes);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/ipp',
        'Content-Length': body.length.toString(),
      },
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final respBytes = response.bodyBytes;
      if (respBytes.length >= 4) {
        final ippStatus = (respBytes[2] << 8) | respBytes[3];
        return ippStatus <= 0x00FF;
      }
      return true;
    }
    return false;
  }

  static Uint8List _buildIppPrintJobRequest({
    required String jobName,
    required String printerUri,
  }) {
    final buf = BytesBuilder();
    buf.addByte(0x02);
    buf.addByte(0x00);
    buf.addByte(0x00);
    buf.addByte(0x02);
    buf.addByte(0x00);
    buf.addByte(0x00);
    buf.addByte(0x00);
    buf.addByte(0x01);
    buf.addByte(0x01);
    _addIppAttribute(buf, 0x47, 'attributes-charset', 'utf-8');
    _addIppAttribute(buf, 0x48, 'attributes-natural-language', 'en');
    _addIppAttribute(buf, 0x45, 'printer-uri', printerUri);
    _addIppAttribute(buf, 0x42, 'job-name', jobName);
    _addIppAttribute(buf, 0x49, 'document-format', 'application/pdf');
    buf.addByte(0x03);
    return buf.toBytes();
  }

  static void _addIppAttribute(
    BytesBuilder buf,
    int valueTag,
    String name,
    String value,
  ) {
    final nameBytes = name.codeUnits;
    final valueBytes = value.codeUnits;
    buf.addByte(valueTag);
    buf.addByte((nameBytes.length >> 8) & 0xFF);
    buf.addByte(nameBytes.length & 0xFF);
    buf.add(nameBytes);
    buf.addByte((valueBytes.length >> 8) & 0xFF);
    buf.addByte(valueBytes.length & 0xFF);
    buf.add(valueBytes);
  }

  // ─── Public Print Methods ─────────────────────────────────────────────────

  /// Mencetak foto ke Epson L8050.
  /// Strategi: Native Android Print → IPP → Printing plugin fallback.
  static Future<PrintJobResult> printPhotoBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
  }) async {
    try {
      final ip = await getIpAddress();
      debugPrint('🖨️ Memproses foto untuk dicetak ke Epson L8050 ($ip)...');

      // 1. ★ Coba native Android PrintManager (via Epson Print Enabler)
      //    Ini langsung menggunakan driver Epson yang sudah terpasang di tablet.
      if (Platform.isAndroid) {
        try {
          debugPrint('🖨️ Mencoba native Android PrintManager (Epson Print Enabler)...');
          final nativeSuccess = await _printViaNativeChannel(
            imageBytes: imageBytes,
            jobName: jobName,
          );
          if (nativeSuccess) {
            debugPrint('✅ Native print berhasil dikirim');
            return const PrintJobResult(
              isSuccess: true,
              message: 'Foto berhasil dikirim ke printer Epson L8050',
              printerName: 'Epson L8050 (Native Print)',
              isDirect: true,
            );
          }
        } catch (e) {
          debugPrint('Native print error: $e');
        }
      }

      // 2. Build PDF untuk IPP / fallback
      final pdfBytes = await _buildPhotoPdf(imageBytes);
      debugPrint('🖨️ PDF 4×6 siap: ${pdfBytes.length} bytes');

      // 3. Coba IPP
      try {
        final ippSuccess = await _trySendIpp(
          printerIp: ip,
          pdfBytes: pdfBytes,
          jobName: jobName,
        );
        if (ippSuccess) {
          return PrintJobResult(
            isSuccess: true,
            message: 'Foto berhasil dicetak via IPP',
            printerName: 'Epson L8050 ($ip)',
            isDirect: true,
          );
        }
      } catch (e) {
        debugPrint('IPP gagal: $e');
      }

      // 4. Fallback: Printing plugin layoutPdf
      debugPrint('🖨️ Fallback → Printing.layoutPdf...');
      final layoutSuccess = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: jobName,
        format: const PdfPageFormat(
          4.0 * PdfPageFormat.inch,
          6.0 * PdfPageFormat.inch,
        ),
      );

      if (layoutSuccess) {
        return const PrintJobResult(
          isSuccess: true,
          message: 'Foto berhasil dikirim ke printer.',
          printerName: 'Epson L8050',
          isDirect: false,
        );
      } else {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Pencetakan dibatalkan.',
          printerName: 'Epson L8050',
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

  /// Cetak halaman uji.
  static Future<PrintJobResult> printTestPage() async {
    try {
      final ip = await getIpAddress();
      debugPrint('🖨️ Menyiapkan Test PDF 4×6...');

      final pdfBytes = await compute(_buildTestPdf, 0);
      debugPrint('🖨️ Test PDF: ${pdfBytes.length} bytes');

      // Coba native print (PDF)
      if (Platform.isAndroid) {
        try {
          final nativeSuccess = await _printPdfViaNativeChannel(
            pdfBytes: pdfBytes,
            jobName: 'Test_Page',
          );
          if (nativeSuccess) {
            return const PrintJobResult(
              isSuccess: true,
              message: 'Test page berhasil dikirim (Native Print)',
              printerName: 'Epson L8050',
              isDirect: true,
            );
          }
        } catch (e) {
          debugPrint('Native test print error: $e');
        }
      }

      // Coba IPP
      try {
        final ippSuccess = await _trySendIpp(
          printerIp: ip,
          pdfBytes: pdfBytes,
          jobName: 'Test_Page',
        );
        if (ippSuccess) {
          return PrintJobResult(
            isSuccess: true,
            message: 'Test page dicetak via IPP',
            printerName: 'Epson L8050 ($ip)',
            isDirect: true,
          );
        }
      } catch (e) {
        debugPrint('IPP test page gagal: $e');
      }

      // Fallback
      final layoutSuccess = await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Test_Page',
        format: const PdfPageFormat(
          4.0 * PdfPageFormat.inch,
          6.0 * PdfPageFormat.inch,
        ),
      );

      if (layoutSuccess) {
        return const PrintJobResult(
          isSuccess: true,
          message: 'Test page berhasil dikirim.',
          printerName: 'Epson L8050',
          isDirect: false,
        );
      } else {
        return const PrintJobResult(
          isSuccess: false,
          message: 'Test page dibatalkan.',
          printerName: 'Epson L8050',
        );
      }
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
}

// ─── Isolate functions (top-level, no class state) ────────────────────────────

/// Build PDF 4×6 dari image bytes — dijalankan di isolate terpisah.
Future<Uint8List> _buildPdfInIsolate(Uint8List imageBytes) async {
  final decoded = img.decodeImage(imageBytes);
  Uint8List jpegBytes;

  if (decoded != null) {
    final resized = img.copyResize(
      decoded,
      width: decoded.width,
      height: decoded.height,
      interpolation: img.Interpolation.linear,
    );
    jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  } else {
    jpegBytes = imageBytes;
  }

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

/// Build test PDF 4×6 sederhana — dijalankan di isolate.
Future<Uint8List> _buildTestPdf(int _) async {
  final doc = pw.Document();
  const pageFormat = PdfPageFormat(
    4.0 * PdfPageFormat.inch,
    6.0 * PdfPageFormat.inch,
    marginAll: 0,
  );
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'HALAMAN UJI PRINTER',
              // ignore: prefer_const_constructors
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Epson L8050 — Fakultas Kopi Photobooth'),
            pw.SizedBox(height: 8),
            pw.Text('Ukuran kertas: 4 x 6 inch'),
            pw.SizedBox(height: 16),
            pw.Text('Jika halaman ini tercetak dengan benar,'),
            pw.Text('printer terhubung dan siap digunakan.'),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
