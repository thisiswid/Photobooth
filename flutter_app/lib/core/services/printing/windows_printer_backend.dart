import 'dart:typed_data';

import 'dart:ui' show ImageDescriptor, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'windows_printer_status.dart';

/// Backend cetak untuk Windows.
///
/// ─────────────────────────────────────────────────────────────────────────
/// KENAPA JAUH LEBIH SEDERHANA DARIPADA JALUR ANDROID
///
/// Di Android, `PrintManager.print()` SELALU membuka dialog spooler — tidak ada
/// API silent print. Jalur Android karenanya butuh Accessibility Service untuk
/// menekan tombol Print, plus overlay untuk menutupi dialognya dari pelanggan.
///
/// Di Windows tidak ada aturan itu. Driver Epson resmi yang melakukan
/// rasterisasi ESC/P-R, dan aplikasi cukup mengirim PDF ke spooler.
/// Tidak ada dialog, tidak ada Accessibility, tidak ada overlay.
/// ─────────────────────────────────────────────────────────────────────────
///
/// HASIL SPIKE C0 (terbukti 2026-09-01, jangan diubah tanpa uji ulang):
///
/// - Ukuran kertas : 4x6 inci (101,6 x 152,4 mm)
/// - Bleed         : 0 di keempat sisi — TIDAK diperlukan sama sekali
/// - Borderless    : diatur di driver, BUKAN dari aplikasi
/// - Tempat setelan: Printer Properties > Advanced > **Printing Defaults**
///                   (BUKAN "Printing Preferences" dari klik kanan printer —
///                   yang itu tidak terbaca oleh aplikasi, dan menjadi sebab
///                   print queue terus menunjukkan A4)
///
/// Parameter `format:` pada `directPrintPdf` HANYA menentukan ukuran kanvas
/// PDF. Ukuran kertas sesungguhnya datang dari DEVMODE default printer.
///
/// Kertas 2x6 sungguhan MUSTAHIL di L8050: User-Defined Paper Size mentok pada
/// lebar minimum 89 mm, sedangkan 2 inci = 50,8 mm. Strip karenanya dicetak
/// dua-up di atas kertas 4R lalu dipotong tengah. Konsekuensi baiknya: ukuran
/// kertas TIDAK PERNAH berubah antar job, jadi tidak perlu mengubah DEVMODE
/// per job dan package `printing` sudah mencukupi.
class WindowsPrinterBackend {
  WindowsPrinterBackend._();

  static const _storage = FlutterSecureStorage();
  static const _selectedPrinterKey = 'windows_selected_printer';
  static const _usePrinterSettingsKey = 'windows_use_printer_settings';

  /// 4R = 4 x 6 inci, tanpa margin. Hasil C0.
  static final PdfPageFormat page4R = PdfPageFormat(
    4 * PdfPageFormat.inch,
    6 * PdfPageFormat.inch,
    marginAll: 0,
  );

  /// Versi mendatar dari [page4R], dipakai bila foto berorientasi lanskap.
  static final PdfPageFormat page4RLandscape = PdfPageFormat(
    6 * PdfPageFormat.inch,
    4 * PdfPageFormat.inch,
    marginAll: 0,
  );

  /// Apakah job dikirim memakai DEVMODE milik driver (`true`) atau memakai
  /// ukuran halaman dari aplikasi (`false`).
  ///
  /// DEFAULT `true`, dan ini penting: ukuran kertas serta borderless HANYA
  /// dikenali kalau job memakai setelan driver. Dengan `false`, package
  /// `printing` menimpa DEVMODE dengan ukuran dari parameter `format:`, dan
  /// driver Epson kehilangan konteks borderless-nya — hasilnya bertepi putih
  /// walaupun Printing Defaults sudah disetel 4x6 borderless.
  ///
  /// Ini persis temuan spike C0: yang berhasil adalah tombol
  /// "CETAK UJI (setelan driver)".
  static Future<bool> getUsePrinterSettings() async {
    try {
      return (await _storage.read(key: _usePrinterSettingsKey)) != 'false';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setUsePrinterSettings(bool v) async {
    try {
      await _storage.write(key: _usePrinterSettingsKey, value: v.toString());
    } catch (_) {}
  }

  // ─── Pemilihan printer ────────────────────────────────────────────────────

  static Future<List<Printer>> listPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('⚠️ [WinPrint] Gagal listPrinters: $e');
      return const [];
    }
  }

  static Future<String?> getSelectedPrinterName() async {
    try {
      return await _storage.read(key: _selectedPrinterKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSelectedPrinterName(String name) async {
    try {
      await _storage.write(key: _selectedPrinterKey, value: name);
      debugPrint('🖨️ [WinPrint] Printer dipilih: $name');
    } catch (e) {
      debugPrint('⚠️ [WinPrint] Gagal menyimpan pilihan printer: $e');
    }
  }

  /// Menentukan printer yang dipakai, berurutan:
  /// 1. yang pernah dipilih operator di panel settings
  /// 2. printer yang namanya mengandung "l8050" atau "epson"
  /// 3. printer default Windows
  /// 4. printer pertama yang ada
  static Future<Printer?> resolvePrinter() async {
    final printers = await listPrinters();
    if (printers.isEmpty) return null;

    final saved = await getSelectedPrinterName();
    if (saved != null && saved.isNotEmpty) {
      for (final p in printers) {
        if (p.name == saved) return p;
      }
      debugPrint('⚠️ [WinPrint] Printer tersimpan "$saved" tidak ditemukan, '
          'jatuh ke deteksi otomatis.');
    }

    for (final p in printers) {
      final n = p.name.toLowerCase();
      if (n.contains('l8050') || n.contains('epson')) return p;
    }

    for (final p in printers) {
      if (p.isDefault) return p;
    }
    return printers.first;
  }

  // ─── Status ───────────────────────────────────────────────────────────────

  /// Status printer untuk UI dan telemetri heartbeat.
  ///
  /// CATATAN: package `printing` tidak mengekspos status spooler yang
  /// sesungguhnya — kertas habis, tinta habis, job macet. Untuk itu diperlukan
  /// `printing_ffi` atau `windows_printer` yang memanggil Win32 spooler API.
  /// Item tersebut dicatat sebagai C0-5 dan masih terbuka.
  ///
  /// Sementara ini status dibedakan menjadi: printer terdaftar di spooler
  /// (`ready`) atau tidak ditemukan sama sekali (`offline`). Itu sudah lebih
  /// akurat daripada jalur Android yang hanya menebak lewat ping soket.
  static Future<Map<String, dynamic>> getStatus() async {
    final printers = await listPrinters();
    final printer = await resolvePrinter();

    if (printers.isEmpty) {
      return {
        'status': PrinterHealth.offline.code,
        'message': 'Tidak ada printer terdaftar di Windows.',
        'printerName': null,
        'totalPrinters': 0,
        'canPrint': false,
        'detailStatusAvailable': false,
      };
    }
    if (printer == null) {
      return {
        'status': PrinterHealth.offline.code,
        'message': 'Printer target tidak ditemukan.',
        'printerName': null,
        'totalPrinters': printers.length,
        'canPrint': false,
        'detailStatusAvailable': false,
      };
    }

    // Status sungguhan dari WMI: kertas habis, tinta habis, macet, dsb.
    final health = await WindowsPrinterStatus.read(printer.name);
    if (health == null) {
      // WMI gagal dibaca — jangan mengarang. Turunkan ke fakta yang pasti:
      // printer terdaftar di spooler.
      return {
        'status': PrinterHealth.unknown.code,
        'message': 'Printer terdaftar (${printer.name}), '
            'status rinci tidak terbaca.',
        'printerName': printer.name,
        'isDefault': printer.isDefault,
        'totalPrinters': printers.length,
        'canPrint': true,
        'detailStatusAvailable': false,
      };
    }

    return {
      'status': health.code,
      'message': health.message,
      'printerName': printer.name,
      'isDefault': printer.isDefault,
      'totalPrinters': printers.length,
      'canPrint': health.canPrint,
      'needsAttention': health.needsAttention,
      'detailStatusAvailable': true,
    };
  }

  /// Kondisi printer sebagai enum. Dipakai heartbeat dan panel settings.
  static Future<PrinterHealth> health() async {
    final printer = await resolvePrinter();
    if (printer == null) return PrinterHealth.offline;
    return (await WindowsPrinterStatus.read(printer.name)) ??
        PrinterHealth.unknown;
  }

  /// "Terjangkau" di Windows berarti masih layak menerima job — bukan sekadar
  /// terdaftar. Printer yang kertasnya habis TIDAK dianggap terjangkau, supaya
  /// kiosk berhenti menerima pesanan sebelum pelanggan terlanjur membayar.
  static Future<bool> isReachable() async {
    final h = await health();
    // unknown tetap dianggap layak: lebih baik mencoba mencetak daripada
    // menolak pesanan hanya karena WMI tidak terbaca.
    return h.canPrint || h == PrinterHealth.unknown;
  }

  // ─── Cetak ────────────────────────────────────────────────────────────────

  /// Mengirim foto ke printer TANPA dialog.
  ///
  /// [copies] dikirim sebagai halaman berulang dalam SATU job, bukan beberapa
  /// job terpisah — supaya urutannya terjaga dan lebih mudah dibatalkan.
  ///
  /// [orientation] menerima 'Auto' | 'Portrait' | 'Landscape'. Pada 'Auto',
  /// orientasi mengikuti bentuk gambarnya. Ini sekaligus melunasi utang teknis
  /// lama: `orientation` dan `copies` selama ini disimpan di settings tapi
  /// tidak pernah dibaca jalur cetak mana pun.
  static Future<WindowsPrintOutcome> printImageBytes({
    required Uint8List imageBytes,
    String jobName = 'Photobooth_Print',
    int copies = 1,
    String orientation = 'Auto',
  }) async {
    final printer = await resolvePrinter();
    if (printer == null) {
      return const WindowsPrintOutcome(
        isSuccess: false,
        message: 'Tidak ada printer yang bisa dipakai. '
            'Pastikan driver Epson L8050 terpasang.',
      );
    }

    final safeCopies = copies.clamp(1, 10);
    final format = await _resolveFormat(imageBytes, orientation);

    final useDriverSettings = await getUsePrinterSettings();
    debugPrint('🖨️ [WinPrint] Kirim ke "${printer.name}" — '
        '${(format.width / PdfPageFormat.mm).toStringAsFixed(1)}x'
        '${(format.height / PdfPageFormat.mm).toStringAsFixed(1)} mm, '
        '$safeCopies lembar, '
        'setelan=${useDriverSettings ? "DRIVER" : "APLIKASI"}');

    try {
      final ok = await Printing.directPrintPdf(
        printer: printer,
        name: jobName,
        format: format,
        usePrinterSettings: useDriverSettings,
        onLayout: (_) => _buildPhotoPdf(
          imageBytes: imageBytes,
          format: format,
          copies: safeCopies,
        ),
      );
      if (ok) {
        return WindowsPrintOutcome(
          isSuccess: true,
          message: 'Cetak dikirim ke ${printer.name}.',
          printerName: printer.name,
        );
      }
      return WindowsPrintOutcome(
        isSuccess: false,
        message: 'Printer menolak atau membatalkan job.',
        printerName: printer.name,
      );
    } catch (e) {
      debugPrint('❌ [WinPrint] Gagal cetak: $e');
      return WindowsPrintOutcome(
        isSuccess: false,
        message: 'Error cetak: $e',
        printerName: printer.name,
      );
    }
  }

  /// Halaman uji: bingkai tepi + tulisan, hemat tinta (~1% coverage).
  /// Isinya sengaja tetap supaya dua hasil cetak bisa dibandingkan langsung.
  static Future<WindowsPrintOutcome> printTestPage() async {
    final printer = await resolvePrinter();
    if (printer == null) {
      return const WindowsPrintOutcome(
        isSuccess: false,
        message: 'Tidak ada printer yang bisa dipakai.',
      );
    }
    try {
      final useDriverSettings = await getUsePrinterSettings();
      debugPrint('🖨️ [WinPrint] Halaman uji ke "${printer.name}", '
          'setelan=${useDriverSettings ? "DRIVER" : "APLIKASI"}');
      final ok = await Printing.directPrintPdf(
        printer: printer,
        name: 'SnapTechBooth Test Page',
        format: page4R,
        usePrinterSettings: useDriverSettings,
        onLayout: (_) => _buildTestPdf(page4R),
      );
      return WindowsPrintOutcome(
        isSuccess: ok,
        message: ok
            ? 'Halaman uji dikirim ke ${printer.name}.'
            : 'Printer menolak halaman uji.',
        printerName: printer.name,
      );
    } catch (e) {
      return WindowsPrintOutcome(
        isSuccess: false,
        message: 'Error halaman uji: $e',
        printerName: printer.name,
      );
    }
  }

  // ─── Pembentuk PDF ────────────────────────────────────────────────────────

  static Future<PdfPageFormat> _resolveFormat(
      Uint8List bytes, String orientation) async {
    switch (orientation) {
      case 'Portrait':
        return page4R;
      case 'Landscape':
        return page4RLandscape;
      default:
        final desc = await ImageDescriptor.encoded(
            await ImmutableBuffer.fromUint8List(bytes));
        final isLandscape = desc.width > desc.height;
        desc.dispose();
        return isLandscape ? page4RLandscape : page4R;
    }
  }

  static Future<Uint8List> _buildPhotoPdf({
    required Uint8List imageBytes,
    required PdfPageFormat format,
    required int copies,
  }) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    for (var i = 0; i < copies; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Container(
            width: double.infinity,
            height: double.infinity,
            // BoxFit.cover: penuhi seluruh halaman, sisi berlebih dipotong.
            // Untuk cetak foto ini yang benar — jangan pernah menyisakan
            // bidang putih hanya demi menampilkan seluruh gambar.
            child: pw.Image(image, fit: pw.BoxFit.cover),
          ),
        ),
      );
    }
    return doc.save();
  }

  static Future<Uint8List> _buildTestPdf(PdfPageFormat format) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
        ),
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 0.4),
            ),
          ),
        ),
        pw.Positioned(
            top: 1.5 * PdfPageFormat.mm,
            left: 0,
            right: 0,
            child: pw.Center(
                child: pw.Text('ATAS',
                    style: const pw.TextStyle(fontSize: 6)))),
        pw.Positioned(
            bottom: 1.5 * PdfPageFormat.mm,
            left: 0,
            right: 0,
            child: pw.Center(
                child: pw.Text('BAWAH',
                    style: const pw.TextStyle(fontSize: 6)))),
        pw.Positioned(
            left: 1.5 * PdfPageFormat.mm,
            top: format.height / 2 - 3,
            child: pw.Text('KIRI', style: const pw.TextStyle(fontSize: 6))),
        pw.Positioned(
            right: 1.5 * PdfPageFormat.mm,
            top: format.height / 2 - 3,
            child: pw.Text('KANAN', style: const pw.TextStyle(fontSize: 6))),
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('SNAPTECHBOOTH',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('TEST PRINT', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 3),
              pw.Text('BORDERLESS CHECK',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ),
      ]),
    ));
    return doc.save();
  }
}

/// Hasil satu percobaan cetak di Windows.
class WindowsPrintOutcome {
  const WindowsPrintOutcome({
    required this.isSuccess,
    required this.message,
    this.printerName,
  });

  final bool isSuccess;
  final String message;
  final String? printerName;
}
