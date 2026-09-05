import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Membaca status printer sesungguhnya dari Windows.
///
/// ─────────────────────────────────────────────────────────────────────────
/// KENAPA INI PENTING
///
/// Di Android status printer MUSTAHIL dibaca — jalur cetak hanya bisa menebak
/// lewat ping soket ke IP, dan printer USB bahkan selalu dianggap tidak
/// terjangkau. Akibatnya kiosk baru tahu kertas habis setelah pelanggan
/// membayar dan menunggu cetakan yang tidak pernah keluar.
///
/// Kemampuan membaca status ini adalah tujuan G-2 di PRD, salah satu dari empat
/// alasan bernama migrasi ke Windows.
/// ─────────────────────────────────────────────────────────────────────────
///
/// KENAPA LEWAT POWERSHELL, BUKAN FFI
///
/// Alternatifnya memanggil Win32 spooler API (`OpenPrinter` / `GetPrinter`)
/// lewat `dart:ffi`, atau menambah package pembungkus seperti `printing_ffi`.
/// Keduanya lebih cepat, tapi menambah permukaan risiko: struct FFI yang salah
/// ukuran menyebabkan crash yang sulit dilacak, dan package pembungkus menambah
/// dependency yang belum tentu terpelihara.
///
/// Di sini status hanya dibaca sekali per 60 detik oleh heartbeat, dan sesekali
/// oleh panel settings. Biaya memanggil PowerShell (~200-400 ms) tidak terasa
/// pada frekuensi itu, sementara kodenya bisa dibaca, diuji manual di terminal,
/// dan tidak bisa membuat aplikasi crash.
///
/// Kalau suatu saat status perlu dibaca berkali-kali per detik, barulah pindah
/// ke FFI — bukan sekarang.
class WindowsPrinterStatus {
  WindowsPrinterStatus._();

  /// Batas waktu memanggil PowerShell. Kalau lewat, dianggap tidak diketahui
  /// dan pemanggil memakai status cadangan — bukan menggantung.
  static const _timeout = Duration(seconds: 6);

  /// Membaca status satu printer berdasarkan namanya di Windows.
  /// Mengembalikan null bila gagal — pemanggil WAJIB menyiapkan cadangan.
  static Future<PrinterHealth?> read(String printerName) async {
    if (!Platform.isWindows) return null;

    // Kutip tunggal di dalam filter WMI di-escape dengan menggandakannya.
    final safeName = printerName.replaceAll("'", "''");
    final script = "Get-CimInstance Win32_Printer -Filter \"Name='$safeName'\" "
        "| Select-Object -First 1 PrinterStatus,DetectedErrorState,WorkOffline,PrinterState "
        "| ConvertTo-Json -Compress";

    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        stdoutEncoding: const SystemEncoding(),
      ).timeout(_timeout);

      final out = (res.stdout as String).trim();
      if (out.isEmpty) {
        debugPrint('⚠️ [WinStatus] Printer "$printerName" tidak ditemukan di WMI.');
        return null;
      }

      final map = jsonDecode(out);
      if (map is! Map) return null;

      return PrinterHealth.fromWmi(
        printerStatus: _asInt(map['PrinterStatus']),
        detectedErrorState: _asInt(map['DetectedErrorState']),
        workOffline: map['WorkOffline'] == true,
      );
    } catch (e) {
      debugPrint('⚠️ [WinStatus] Gagal membaca status printer: $e');
      return null;
    }
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Kondisi printer yang bisa ditindaklanjuti operator.
///
/// Nilai `code` inilah yang dikirim ke backend lewat heartbeat, jadi jangan
/// diubah tanpa menyesuaikan sisi admin dashboard.
enum PrinterHealth {
  ready('ready', 'Printer siap.'),
  printing('printing', 'Sedang mencetak.'),
  outOfPaper('out_of_paper', 'KERTAS HABIS — isi ulang kertas foto.'),
  lowPaper('low_paper', 'Kertas menipis.'),
  noInk('no_ink', 'TINTA HABIS — isi ulang tinta.'),
  lowInk('low_ink', 'Tinta menipis.'),
  paperJam('paper_jam', 'KERTAS MACET — periksa jalur kertas.'),
  doorOpen('door_open', 'Penutup printer terbuka.'),
  outputBinFull('output_bin_full', 'Baki keluaran penuh.'),
  paused('paused', 'Antrean cetak sedang di-pause.'),
  offline('offline', 'Printer offline atau tidak tersambung.'),
  error('error', 'Printer melaporkan error.'),
  unknown('unknown', 'Status printer tidak diketahui.');

  const PrinterHealth(this.code, this.message);

  /// Dikirim ke backend. Jangan diubah sepihak.
  final String code;

  /// Kalimat untuk operator, bukan untuk pelanggan.
  final String message;

  /// True bila kiosk masih layak menerima pesanan baru.
  bool get canPrint =>
      this == PrinterHealth.ready ||
      this == PrinterHealth.printing ||
      this == PrinterHealth.lowPaper ||
      this == PrinterHealth.lowInk;

  /// True bila butuh tangan manusia sekarang juga.
  bool get needsAttention => !canPrint;

  /// Memetakan nilai WMI `Win32_Printer` ke kondisi di atas.
  ///
  /// DetectedErrorState (yang paling informatif):
  ///   2 No Error · 3 Low Paper · 4 No Paper · 5 Low Toner · 6 No Toner
  ///   7 Door Open · 8 Jammed · 9 Offline · 10 Service Requested
  ///   11 Output Bin Full
  ///
  /// PrinterStatus: 3 Idle · 4 Printing · 5 Warmup · 6 Stopped · 7 Offline
  static PrinterHealth fromWmi({
    int? printerStatus,
    int? detectedErrorState,
    bool workOffline = false,
  }) {
    // Offline diperiksa lebih dulu: kalau kabel dicabut, nilai error state
    // lain menjadi tidak bermakna.
    if (workOffline || printerStatus == 7 || detectedErrorState == 9) {
      return PrinterHealth.offline;
    }

    switch (detectedErrorState) {
      case 4:
        return PrinterHealth.outOfPaper;
      case 3:
        return PrinterHealth.lowPaper;
      case 6:
        return PrinterHealth.noInk;
      case 5:
        return PrinterHealth.lowInk;
      case 8:
        return PrinterHealth.paperJam;
      case 7:
        return PrinterHealth.doorOpen;
      case 11:
        return PrinterHealth.outputBinFull;
      case 10:
      case 1:
        return PrinterHealth.error;
    }

    switch (printerStatus) {
      case 4:
        return PrinterHealth.printing;
      case 3:
      case 5:
        return PrinterHealth.ready;
      case 6:
        return PrinterHealth.paused;
    }

    // detectedErrorState == 2 (No Error) tapi PrinterStatus tidak dikenal.
    if (detectedErrorState == 2) return PrinterHealth.ready;
    return PrinterHealth.unknown;
  }
}
