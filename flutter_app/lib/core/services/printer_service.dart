import 'dart:io' show Platform, Socket;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'error_logger.dart';
import 'ipp/ipp_client.dart';
import 'printing/windows_printer_backend.dart';
import 'printing/windows_printer_status.dart';
import 'ipp/network_scan.dart';

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
  static const _printingEnabledKey = 'printer_printing_enabled';
  static const _autoReconnectKey = 'printer_auto_reconnect';
  static const _retryCountKey = 'printer_retry_count';
  static const _marginHorizKey = 'printer_margin_horizontal';
  static const _marginVertKey = 'printer_margin_vertical';
  static const _marginUnitKey = 'printer_margin_unit';
  static const _ippEnabledKey = 'printer_ipp_enabled';
  static const _ippPortKey = 'printer_ipp_port';
  static const _bindWifiKey = 'printer_bind_wifi';
  static const _autoDiscoverKey = 'printer_ipp_autodiscover';
  static const _strictSilentKey = 'printer_strict_silent';
  static const _coverDialogKey = 'printer_cover_dialog';

  static String? _cachedIp;
  static bool _isPrintingBusy = false; // Lock guard agar tidak ada print bersamaan / ganda

  /// Alasan kegagalan jalur IPP terakhir — ditampilkan di panel diagnostik
  /// supaya operator tahu kenapa sistem jatuh ke fallback PrintManager.
  /// Auto-discovery hanya dicoba SEKALI per sesi aplikasi. Pemindaian subnet
  /// makan 5-10 detik; mengulanginya di setiap cetak akan menahan antrian
  /// pelanggan setiap kali printer memang tidak ada di jaringan.
  static bool _autoDiscoverAttempted = false;

  static String? lastIppFailure;

  /// True bila cetak terakhir benar-benar silent (lewat IPP, tanpa dialog).
  static bool lastPrintWasSilent = false;

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

  /// Saklar utama cetak.
  ///
  /// Saat dimatikan, seluruh permintaan cetak dilewati dan dilaporkan sukses
  /// tanpa mengirim apa pun ke printer. Gunanya untuk menguji alur sesi
  /// berulang kali tanpa menghabiskan kertas dan tinta.
  ///
  /// Default MENYALA — kiosk yang baru dipasang harus mencetak, bukan diam.
  static Future<bool> getPrintingEnabled() async =>
      (await _storage.read(key: _printingEnabledKey)) != 'false';

  static Future<void> setPrintingEnabled(bool b) async {
    await _storage.write(key: _printingEnabledKey, value: b.toString());
    debugPrint(b
        ? '🖨️ Mode cetak DINYALAKAN'
        : '🚫 Mode cetak DIMATIKAN — permintaan cetak akan dilewati');
  }

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

  /// Jalur IPP langsung (silent, tanpa dialog print preview).
  ///
  /// Default MATI. Epson L8050 — printer yang dipakai kiosk ini — TIDAK
  /// mendukung IPP sama sekali: tidak ada IPP-over-USB (probe USB), dan Web
  /// Config-nya tidak punya halaman AirPrint maupun bagian IPP di Services >
  /// Protocol. Membiarkannya menyala hanya menambah beberapa detik percobaan
  /// socket yang pasti gagal di setiap cetak, sementara pelanggan menunggu.
  ///
  /// Nyalakan HANYA bila printer diganti dengan model yang mendukung
  /// AirPrint/Mopria — seluruh implementasi IPP sudah siap pakai.
  static Future<bool> getIppEnabled() async => (await _storage.read(key: _ippEnabledKey)) == 'true';
  static Future<void> setIppEnabled(bool b) async => await _storage.write(key: _ippEnabledKey, value: b.toString());

  static Future<int> getIppPort() async => int.tryParse(await _storage.read(key: _ippPortKey) ?? '631') ?? 631;
  static Future<void> setIppPort(int p) async => await _storage.write(key: _ippPortKey, value: p.toString());

  /// Ikat proses ke Network Wi-Fi sebelum bicara ke printer. Default AKTIF.
  ///
  /// Diperlukan karena Android mengalihkan trafik aplikasi ke jaringan lain
  /// bila Wi-Fi dianggap "tanpa internet" — kondisi normal untuk router printer
  /// atau Wi-Fi Direct. Tanpa binding, socket ke IP printer gagal meski printer
  /// jelas sejaring.
  static Future<bool> getBindWifi() async => (await _storage.read(key: _bindWifiKey)) != 'false';
  static Future<void> setBindWifi(bool b) async => await _storage.write(key: _bindWifiKey, value: b.toString());

  /// Cari printer otomatis di subnet bila IP tersimpan tidak menjawab.
  /// Default AKTIF — supaya operator tidak perlu tahu IP printer sama sekali.
  static Future<bool> getIppAutoDiscover() async => (await _storage.read(key: _autoDiscoverKey)) != 'false';
  static Future<void> setIppAutoDiscover(bool b) async => await _storage.write(key: _autoDiscoverKey, value: b.toString());

  /// Mode ketat: JANGAN PERNAH buka dialog cetak Android.
  ///
  /// Bila aktif dan IPP gagal, cetak dinyatakan gagal dengan pesan jelas —
  /// bukan diam-diam jatuh ke PrintManager yang memunculkan dialog. Ini yang
  /// menjamin layar kiosk tidak pernah menampilkan halaman print bawaan.
  ///
  /// Konsekuensinya: kalau printer tidak terjangkau lewat jaringan, kiosk
  /// tidak mencetak sama sekali. Itu memang tujuannya — kegagalan terlihat,
  /// bukan tersembunyi di balik dialog.
  static Future<bool> getStrictSilent() async => (await _storage.read(key: _strictSilentKey)) == 'true';
  static Future<void> setStrictSilent(bool b) async => await _storage.write(key: _strictSilentKey, value: b.toString());

  /// Tutupi dialog cetak Android dengan layar kiosk sendiri. Default AKTIF.
  ///
  /// Android tidak mengizinkan cetak tanpa membuka print spooler. Yang bisa
  /// dilakukan adalah menutupinya, sehingga pelanggan hanya melihat layar
  /// "Mencetak foto Anda...". Dialognya tetap ada di baliknya dan tetap
  /// ditekan oleh KioskAutoPrintService.
  ///
  /// Butuh izin "Display over other apps". Tanpa izin itu penutup dilewati
  /// diam-diam dan dialog akan terlihat — cetaknya tetap jalan.
  static Future<bool> getCoverDialog() async => (await _storage.read(key: _coverDialogKey)) != 'false';
  static Future<void> setCoverDialog(bool b) async => await _storage.write(key: _coverDialogKey, value: b.toString());

  /// Apakah izin "Display over other apps" sudah diberikan.
  static Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (e) {
      debugPrint('canDrawOverlays error: $e');
      return false;
    }
  }

  /// Buka layar sistem untuk memberikan izin overlay.
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('requestOverlayPermission error: $e');
    }
  }

  /// Lepas paksa lapisan penutup — jaring pengaman bila tersangkut.
  static Future<void> hidePrintCover() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('hidePrintCover');
    } catch (e) {
      debugPrint('hidePrintCover error: $e');
    }
  }

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

  /// Probe seluruh USB interface descriptor untuk menentukan jalur silent print.
  ///
  /// TIDAK butuh USB permission — descriptor terbaca tanpa openDevice().
  ///
  /// Kunci hasilnya:
  /// - `recommendedPath`: `IPP_USB` | `ESCPR_RAW` | `NO_PRINTER_INTERFACE` |
  ///   `NO_EPSON_DEVICE` | `ERROR`
  /// - `ippUsbSupported`: true bila ada interface 7/1/4 → silent print langsung bisa
  /// - `verdict`: penjelasan siap tampil untuk operator
  /// - `rawSummary`: dump descriptor multi-baris untuk di-screenshot
  static Future<Map<String, dynamic>> probeUsbInterfaces() async {
    if (!Platform.isAndroid) {
      return {
        'success': false,
        'totalUsbDevices': 0,
        'epsonPresent': false,
        'ippUsbSupported': false,
        'rawPrinterSupported': false,
        'recommendedPath': 'ERROR',
        'verdict': 'Probe USB hanya tersedia di perangkat Android.',
        'rawSummary': '',
        'devices': <dynamic>[],
      };
    }
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('probeUsbPrinterInterfaces');
      if (res == null) throw Exception('Respon probe kosong');
      debugPrint('🔍 USB probe: ${res['recommendedPath']} — ${res['verdict']}');
      return res;
    } catch (e) {
      debugPrint('USB probe channel error: $e');
      return {
        'success': false,
        'totalUsbDevices': 0,
        'epsonPresent': false,
        'ippUsbSupported': false,
        'rawPrinterSupported': false,
        'recommendedPath': 'ERROR',
        'verdict': 'Gagal menjalankan probe USB: $e',
        'rawSummary': '',
        'devices': <dynamic>[],
      };
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

  /// Status lengkap Kiosk Auto-Print Helper: aktif di Settings, service jalan,
  /// dan hasil percobaan penekanan tombol terakhir.
  static Future<Map<String, dynamic>> getAutoPrintHelperStatus() async {
    if (!Platform.isAndroid) {
      return {
        'enabledInSettings': false,
        'serviceRunning': false,
        'lastResult': 'hanya tersedia di Android',
        'lastSpoolerPackage': '',
      };
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAutoPrintHelperStatus');
      return res ?? const {};
    } catch (e) {
      debugPrint('getAutoPrintHelperStatus error: $e');
      return {
        'enabledInSettings': false,
        'serviceRunning': false,
        'lastResult': 'gagal membaca status: $e',
        'lastSpoolerPackage': '',
      };
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
    // Di Windows, "terjangkau" berarti terdaftar di spooler — bukan soal soket.
    // Printer USB sama sahnya dengan printer jaringan, dan ping ke IP tidak
    // relevan sama sekali. Dipakai juga oleh HeartbeatService.
    if (Platform.isWindows) {
      return WindowsPrinterBackend.isReachable();
    }

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

  /// Kode status printer untuk telemetri heartbeat.
  ///
  /// Windows mengembalikan kondisi sesungguhnya dari WMI: `ready`,
  /// `out_of_paper`, `no_ink`, `paper_jam`, `offline`, dan seterusnya.
  ///
  /// Android hanya bisa membedakan terjangkau atau tidak — bukan keterbatasan
  /// kode ini, melainkan memang tidak ada API-nya.
  static Future<String> getHealthCode() async {
    if (Platform.isWindows) {
      return (await WindowsPrinterBackend.health()).code;
    }
    try {
      return (await isPrinterReachable())
          ? PrinterHealth.ready.code
          : PrinterHealth.offline.code;
    } catch (_) {
      return PrinterHealth.error.code;
    }
  }

  static Future<Map<String, dynamic>> getPrinterStatus() async {
    if (Platform.isWindows) {
      return WindowsPrinterBackend.getStatus();
    }

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

  // ─── Print Engine 1: IPP LANGSUNG (SILENT — tidak ada dialog sama sekali) ──
  //
  // Hasil probe USB (lihat Hidden Device Settings → USB DIAGNOSTIC): Epson L8050
  // TIDAK mengekspos IPP-over-USB — hanya interface printer raw 7/1/2. Karena
  // itu jalur silent yang tersedia adalah IPP lewat jaringan (router maupun
  // Wi-Fi Direct). Jalur ini melewati Android PrintManager sepenuhnya sehingga
  // PrintActivity tidak pernah terbuka dan Accessibility Service tidak perlu
  // menekan tombol apa pun.

  /// Status seluruh Network yang dikenal Android: transport, mana yang aktif,
  /// mana yang tervalidasi, interface dan alamatnya.
  static Future<Map<String, dynamic>> getNetworkDiagnostics() async {
    if (!Platform.isAndroid) {
      return {
        'success': false,
        'wifiPresent': false,
        'wifiIsActive': false,
        'wifiValidated': false,
        'wifiAddresses': <String>[],
        'networkCount': 0,
        'warning': 'Diagnosa jaringan hanya tersedia di Android.',
        'rawSummary': '',
        'networks': <dynamic>[],
      };
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getNetworkDiagnostics');
      return res ?? const {};
    } catch (e) {
      debugPrint('getNetworkDiagnostics error: $e');
      return {
        'success': false,
        'wifiPresent': false,
        'wifiIsActive': false,
        'wifiValidated': false,
        'wifiAddresses': <String>[],
        'networkCount': 0,
        'warning': 'Gagal membaca status jaringan: $e',
        'rawSummary': '',
        'networks': <dynamic>[],
      };
    }
  }

  /// Jalankan [body] dengan proses terikat ke Wi-Fi, lalu SELALU lepas lagi.
  ///
  /// Binding tidak dilepas berarti trafik backend & Pakasir ikut terkunci di
  /// jaringan printer yang tanpa internet — karena itu pelepasannya di `finally`.
  static Future<T> withWifiBinding<T>(Future<T> Function() body) async {
    if (!Platform.isAndroid || !await getBindWifi()) {
      return body();
    }

    var bound = false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('bindProcessToWifi');
      bound = res?['success'] == true;
      if (!bound) {
        debugPrint('⚠️ Binding ke Wi-Fi gagal: ${res?['message']}');
      }
    } catch (e) {
      debugPrint('⚠️ Binding ke Wi-Fi error: $e');
    }

    try {
      return await body();
    } finally {
      if (bound) {
        try {
          await _channel.invokeMethod('unbindProcessNetwork');
        } catch (e) {
          debugPrint('⚠️ Gagal melepas binding jaringan: $e');
        }
      }
    }
  }

  /// Jalankan SELURUH diagnosa jaringan sekali jalan dan rangkum jadi satu
  /// laporan teks siap salin.
  ///
  /// Dibuat karena "printer tidak terjangkau" punya empat sebab yang berbeda
  /// penanganannya, dan membedakannya butuh beberapa pemeriksaan sekaligus:
  /// alamat tablet, routing Android, port printer, dan port gateway.
  ///
  /// Kunci diagnosanya ada pada perbandingan printer vs gateway:
  /// - gateway TERJANGKAU tapi printer TIDAK → tablet ada di LAN yang benar,
  ///   tapi trafik antar-perangkat diblokir router (AP isolation / guest mode),
  ///   atau printer menolak koneksi.
  /// - gateway TIDAK terjangkau juga → tablet tidak berada di LAN itu sama sekali.
  static Future<String> buildDiagnosticReport() async {
    final buf = StringBuffer();
    final targetIp = await getIpAddress();
    final port = await getIppPort();

    buf.writeln('=== DIAGNOSA PRINTER SNAPTECHBOOTH ===');
    buf.writeln('Target printer : $targetIp:$port');
    buf.writeln('');

    // 1. Alamat tablet
    final addrs = await getLocalAddresses();
    buf.writeln('--- ALAMAT TABLET ---');
    if (addrs.isEmpty) {
      buf.writeln('(kosong — tablet tidak punya IPv4 aktif)');
    } else {
      for (final a in addrs) {
        buf.writeln('${a.interfaceName}: ${a.ip}${a.isWifiDirect ? "  [Wi-Fi Direct]" : ""}');
      }
    }
    buf.writeln('');

    // 2. Routing Android
    final diag = await getNetworkDiagnostics();
    buf.writeln('--- ROUTING ANDROID ---');
    buf.writeln('wifiPresent=${diag['wifiPresent']} '
        'wifiIsActive=${diag['wifiIsActive']} '
        'wifiValidated=${diag['wifiValidated']}');
    final warn = diag['warning'] as String? ?? '';
    if (warn.isNotEmpty) buf.writeln('PERINGATAN: $warn');
    final raw = diag['rawSummary'] as String? ?? '';
    if (raw.isNotEmpty) buf.writeln(raw);
    buf.writeln('');

    // 3. Subnet cocok?
    final targetParts = targetIp.split('.');
    final targetPrefix = targetParts.length == 4 ? targetParts.take(3).join('.') : null;
    final sameSubnet = targetPrefix != null &&
        addrs.any((a) => a.subnetPrefix == targetPrefix);
    buf.writeln('--- SUBNET ---');
    buf.writeln(sameSubnet
        ? 'COCOK — tablet berada di $targetPrefix.x, sama dengan printer.'
        : 'TIDAK COCOK — tablet tidak punya alamat di ${targetPrefix ?? "?"}.x');
    buf.writeln('');

    // 4. Port printer
    final printerPorts = await checkPrinterPorts(ip: targetIp);
    buf.writeln('--- PORT PRINTER ($targetIp) ---');
    printerPorts.forEach((k, v) {
      buf.writeln('$k ${v ? "TERBUKA" : "tertutup"}  ${NetworkScan.knownPorts[k] ?? ""}');
    });
    final printerReachable = printerPorts.values.any((v) => v);
    buf.writeln('');

    // 5. Port gateway — pembanding penentu
    var gatewayReachable = false;
    if (targetPrefix != null) {
      final gw = '$targetPrefix.1';
      final gwPorts = await withWifiBinding(() => NetworkScan.checkPorts(gw));
      gatewayReachable = gwPorts.values.any((v) => v);
      buf.writeln('--- PORT GATEWAY ($gw) ---');
      gwPorts.forEach((k, v) {
        if (v) buf.writeln('$k TERBUKA');
      });
      buf.writeln(gatewayReachable ? '(gateway menjawab)' : '(gateway diam total)');
      buf.writeln('');
    }

    // 6. Kesimpulan
    buf.writeln('--- KESIMPULAN ---');
    if (printerReachable) {
      buf.writeln('Printer TERJANGKAU. Masalahnya bukan jaringan — '
          'lanjut cek negosiasi IPP lewat tombol "Cek Kemampuan IPP Printer".');
    } else if (diag['wifiPresent'] != true) {
      buf.writeln('Tablet TIDAK tersambung Wi-Fi. Sambungkan ke SSID yang sama '
          'dengan printer, lalu ulangi.');
    } else if (!sameSubnet) {
      buf.writeln('Tablet berada di jaringan LAIN. Pindahkan tablet ke SSID yang '
          'sama dengan printer.');
    } else if (diag['wifiIsActive'] != true) {
      buf.writeln('Wi-Fi bukan jaringan aktif — Android mengalihkan trafik aplikasi '
          'ke jaringan lain. Nyalakan "Ikat Proses ke Wi-Fi" lalu ulangi.');
    } else if (gatewayReachable) {
      buf.writeln('Tablet SEJARING dengan printer dan gateway menjawab, TAPI printer '
          'diam total. Ini pola khas AP ISOLATION (client isolation / mode tamu) '
          'di router: perangkat boleh ke internet tapi dilarang saling bicara. '
          'Matikan AP isolation di admin router, atau pakai router lain khusus kiosk.');
    } else {
      buf.writeln('Printer maupun gateway sama-sama tidak menjawab. Tablet kemungkinan '
          'tidak benar-benar berada di LAN tersebut meski alamatnya terlihat cocok.');
    }

    return buf.toString();
  }

  /// Daftar IPv4 tablet beserta nama interface-nya (wlan0, p2p0, rndis0, ...).
  static Future<List<LocalAddress>> getLocalAddresses() => NetworkScan.localAddresses();

  /// Cek port printer yang terbuka pada satu IP — membedakan "printer tidak ada
  /// di jaringan" dari "printer ada tapi IPP-nya tertutup".
  static Future<Map<int, bool>> checkPrinterPorts({String? ip}) async {
    final targetIp = ip ?? await getIpAddress();
    return withWifiBinding(() => NetworkScan.checkPorts(targetIp));
  }

  /// Pindai seluruh subnet tablet untuk menemukan printer secara otomatis.
  static Future<List<FoundPrinter>> scanForPrinters({
    void Function(String subnet, int done, int total)? onProgress,
  }) =>
      withWifiBinding(() => NetworkScan.scanAllLocalSubnets(onProgress: onProgress));

  /// Tanya kemampuan printer via IPP. Dipakai panel diagnostik & jalur cetak.
  static Future<IppPrinterInfo> probeIppPrinter({String? ip, int? port}) async {
    final targetIp = ip ?? await getIpAddress();
    final targetPort = port ?? await getIppPort();
    return withWifiBinding(
      () => IppClient.getPrinterAttributes(ip: targetIp, port: targetPort),
    );
  }

  /// Konversi DPI dari setting kualitas.
  static int _dpiFromQuality(String quality) {
    switch (quality.toLowerCase()) {
      case 'low':
        return 200;
      case 'high':
        return 600;
      default:
        return 300;
    }
  }

  /// print-quality enum IPP: 3=draft, 4=normal, 5=high.
  static int _ippQualityFromSetting(String quality) {
    switch (quality.toLowerCase()) {
      case 'low':
        return 3;
      case 'high':
        return 5;
      default:
        return 4;
    }
  }

  /// Siapkan byte dokumen sesuai format yang disepakati printer.
  ///
  /// - `image/jpeg` → pastikan benar-benar JPEG (PNG dikonversi)
  /// - `application/pdf` / `application/octet-stream` → bungkus jadi PDF 4×6
  ///
  /// Dijalankan di isolate (`compute`) karena decode/encode gambar berat dan
  /// akan membekukan UI kiosk bila dijalankan di main isolate.
  static Future<Uint8List> _prepareIppDocument({
    required Uint8List imageBytes,
    required String format,
    required bool borderless,
    required double pageWidthInch,
    required double marginHorizMm,
    required double marginVertMm,
  }) async {
    if (format == 'image/jpeg') {
      return compute(_ensureJpegBytes, imageBytes);
    }
    return compute(_buildPhotoPdf, <String, dynamic>{
      'imageBytes': imageBytes,
      'pageWidthInch': pageWidthInch,
      'marginHorizMm': borderless ? marginHorizMm : marginHorizMm + 5.0,
      'marginVertMm': borderless ? marginVertMm : marginVertMm + 5.0,
    });
  }

  /// Coba cetak lewat IPP. Mengembalikan null bila jalur IPP dimatikan.
  ///
  /// Bila mengembalikan hasil dengan `isSuccess == true`, pemanggil WAJIB
  /// berhenti — jangan lanjut ke PrintManager, karena job sudah diterima
  /// printer dan cetak ganda berarti kertas foto terbuang.
  static Future<PrintJobResult?> _printViaIpp({
    required Uint8List imageBytes,
    required String jobName,
    required int copies,
  }) async {
    if (!await getIppEnabled()) return null;

    var ip = await getIpAddress();
    final port = await getIppPort();

    var info = await probeIppPrinter(ip: ip, port: port);

    // ── Auto-discovery: IP tersimpan tidak menjawab, cari sendiri di subnet ──
    // Ini yang membuat operator tidak perlu tahu IP printer. Dicoba sekali per
    // sesi aplikasi saja supaya kegagalan tidak menahan antrian pelanggan.
    final needDiscovery = !info.reachable || info.workingPath == null;
    if (needDiscovery && !_autoDiscoverAttempted && await getIppAutoDiscover()) {
      _autoDiscoverAttempted = true;
      debugPrint('🔎 IP $ip tidak menjawab — memindai subnet mencari printer...');

      final found = await scanForPrinters();
      FoundPrinter? best;
      for (final f in found) {
        if (f.ippAnswered) {
          best = f;
          break;
        }
      }

      if (best != null) {
        debugPrint('✅ Printer ditemukan otomatis di ${best.ip} — IP disimpan');
        await setIpAddress(best.ip);
        ip = best.ip;
        info = await probeIppPrinter(ip: ip, port: port);
      } else {
        debugPrint('❌ Pemindaian subnet tidak menemukan printer IPP');
      }
    }

    if (!info.reachable) {
      return PrintJobResult(
        isSuccess: false,
        message: info.error ?? 'Printer tidak dapat dijangkau di $ip:$port.',
      );
    }
    if (info.workingPath == null) {
      return PrintJobResult(
        isSuccess: false,
        message: info.error ?? 'Printer tidak menjawab permintaan IPP.',
      );
    }
    final format = info.chosenFormat;
    if (format == null) {
      return PrintJobResult(
        isSuccess: false,
        message: 'Printer tidak mendukung format dokumen yang bisa dihasilkan '
            'aplikasi. Didukung printer: ${info.documentFormats.join(", ")}',
        printerName: info.makeAndModel,
      );
    }
    if (!info.acceptingJobs) {
      return PrintJobResult(
        isSuccess: false,
        message: 'Printer sedang tidak menerima job (state: ${info.stateLabel}'
            '${info.stateReasons.isEmpty ? "" : ", ${info.stateReasons.join(", ")}"}).',
        printerName: info.makeAndModel,
      );
    }

    final borderless = await getBorderless();
    final quality = await getQuality();
    final paperSize = await getPaperSize();
    final marginHoriz = await getMarginHorizontal();
    final marginVert = await getMarginVertical();
    final marginUnit = await getMarginUnit();

    final horizMm = marginUnit == 'cm' ? marginHoriz * 10.0 : marginHoriz;
    final vertMm = marginUnit == 'cm' ? marginVert * 10.0 : marginVert;

    final isStrip = paperSize == '2x6';
    final pageWidthInch = isStrip ? 2.0 : 4.0;

    final doc = await _prepareIppDocument(
      imageBytes: imageBytes,
      format: format,
      borderless: borderless,
      pageWidthInch: pageWidthInch,
      marginHorizMm: horizMm,
      marginVertMm: vertMm,
    );

    // Pakai endpoint PERSIS seperti yang terbukti menjawab saat probe —
    // termasuk port dan TLS-nya. Mengirim job ke 631 padahal yang hidup 443
    // (IPPS) akan gagal tanpa alasan yang jelas.
    final res = await withWifiBinding(() => IppClient.printJob(
      ip: ip,
      port: info.workingPort ?? port,
      useTls: info.workingTls,
      path: info.workingPath,
      documentBytes: doc,
      documentFormat: format,
      jobName: jobName,
      copies: copies,
      borderless: borderless,
      media: isStrip ? 'custom_2x6in_2x6in' : 'na_index-4x6_4x6in',
      mediaWidthHundredthMm: isStrip ? 5080 : 10160,
      mediaHeightHundredthMm: 15240,
      resolutionDpi: _dpiFromQuality(quality),
      printQuality: _ippQualityFromSetting(quality),
    ));

    return PrintJobResult(
      isSuccess: res.isSuccess,
      message: res.isSuccess
          ? 'Cetak silent via IPP berhasil — ${res.message}'
          : 'IPP gagal: ${res.message}',
      printerName: info.makeAndModel ?? 'Epson L8050',
      isDirect: true,
    );
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
      final cover = await getCoverDialog();
      final success = await _channel.invokeMethod<bool>('printPhoto', {
        'imageBytes': imageBytes,
        'jobName': jobName,
        'coverDialog': cover,
        'coverText': 'Mencetak foto Anda...',
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
      final cover = await getCoverDialog();
      final success = await _channel.invokeMethod<bool>('printPdf', {
        'pdfBytes': pdfBytes,
        'jobName': jobName,
        'coverDialog': cover,
        'coverText': 'Mencetak foto Anda...',
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
    // Saklar utama cetak (Hidden Settings > Printer). Diperiksa PALING AWAL,
    // sebelum lock dan sebelum menyentuh printer sama sekali.
    if (!await getPrintingEnabled()) {
      debugPrint('🚫 [Printer] Mode cetak dimatikan — cetakan dilewati '
          '(jobName=$jobName, ${imageBytes.length} byte)');
      return const PrintJobResult(
        isSuccess: true,
        message: 'Mode cetak dimatikan (pengujian) — tidak ada yang dicetak.',
      );
    }

    if (_isPrintingBusy) {
      debugPrint('⚠️ Warning: Print job ditolak karena sedang ada pencetakan berlangsung.');
      return const PrintJobResult(
        isSuccess: false,
        message: 'Printer sedang memproses cetakan lain. Harap tunggu.',
      );
    }
    _isPrintingBusy = true;
    lastPrintWasSilent = false;
    lastIppFailure = null;

    try {
      // ── WINDOWS: langsung ke spooler, tanpa dialog ────────────────────────
      //
      // Tidak ada rantai fallback di sini karena tidak diperlukan: driver Epson
      // resmi yang melakukan rasterisasi ESC/P-R, dan hasilnya sudah terbukti
      // di spike C0 (kertas 4x6, tanpa bleed). Seluruh mesin IPP, Silent Ketat,
      // dan penutup dialog di bawah ini khusus jalur Android.
      if (Platform.isWindows) {
        final copiesSetting = await getCopies();
        final orientation = await getOrientation();

        // Setelan margin dipakai sebagai KOMPENSASI BLEED, bukan tepi kosong.
        //
        // Borderless memperbesar gambar melewati tepi kertas lalu memotong
        // kelebihannya, dan besar perbesaran itu milik driver — tidak bisa
        // dibaca aplikasi. Kompensasi ini menyusutkan bidang gambar sedikit di
        // dalam halaman, sehingga yang dimakan expansion adalah penyangga,
        // bukan tepi frame rancangan admin.
        //
        // POSITIF menyusutkan (kasus umum: tepi frame terpotong).
        // NEGATIF membesarkan (kasus sebaliknya: muncul tepi putih).
        final unit = await getMarginUnit();
        final toMm = unit == 'inch' ? 25.4 : 1.0;
        final compX = (await getMarginHorizontal()) * toMm;
        final compY = (await getMarginVertical()) * toMm;

        debugPrint('🧭 [Print] Kompensasi bleed terbaca: '
            'H=$compX mm, V=$compY mm (unit tersimpan: $unit)');

        final out = await WindowsPrinterBackend.printImageBytes(
          imageBytes: imageBytes,
          jobName: jobName,
          copies: copies > 1 ? copies : copiesSetting,
          orientation: orientation,
          compensationXmm: compX,
          compensationYmm: compY,
        );
        lastPrintWasSilent = out.isSuccess;
        return PrintJobResult(
          isSuccess: out.isSuccess,
          message: out.message,
          printerName: out.printerName ?? 'Epson L8050',
          isDirect: true,
        );
      }

      // ── Jalur 1 (utama): IPP langsung — SILENT, tanpa dialog preview ──
      final ipp = await _printViaIpp(
        imageBytes: imageBytes,
        jobName: jobName,
        copies: copies,
      );
      if (ipp != null) {
        if (ipp.isSuccess) {
          // PENTING: berhenti di sini. Job sudah diterima printer — melanjutkan
          // ke PrintManager berarti mencetak dua kali dan membuang kertas foto.
          lastPrintWasSilent = true;
          return ipp;
        }
        lastIppFailure = ipp.message;
        debugPrint('⚠️ IPP gagal, jatuh ke fallback PrintManager: ${ipp.message}');
      }

      // ── Mode ketat: berhenti di sini, dialog cetak tidak boleh muncul ──
      if (await getStrictSilent()) {
        return PrintJobResult(
          isSuccess: false,
          message: 'Mode Silent Ketat aktif — dialog cetak sengaja tidak dibuka. '
              'IPP gagal: ${lastIppFailure ?? "jalur IPP dimatikan"}',
          printerName: 'Epson L8050',
        );
      }

      // ── Jalur 2 (fallback): Android PrintManager + auto-tap Accessibility ──
      // Jalur ini MEMBUKA dialog print preview; KioskAutoPrintService yang
      // menekan tombolnya. Hanya dipakai bila IPP tidak tersedia/gagal.
      if (!Platform.isAndroid) {
        return PrintJobResult(
          isSuccess: false,
          message: lastIppFailure ?? 'Printing hanya didukung pada perangkat Android.',
        );
      }

      // Jalur ini bergantung penuh pada KioskAutoPrintService untuk menekan
      // tombol Print. Kalau helper-nya mati, dialog akan menggantung menunggu
      // sentuhan orang — di kiosk tanpa penjaga itu berarti sesi macet. Karena
      // itu statusnya diperiksa dan dilaporkan, bukan dibiarkan senyap.
      final helper = await getAutoPrintHelperStatus();
      final helperReady =
          helper['enabledInSettings'] == true && helper['serviceRunning'] == true;

      final success = await _printPhotoViaPrintManager(
        imageBytes: imageBytes,
        jobName: jobName,
      );

      if (success) {
        return PrintJobResult(
          isSuccess: true,
          message: helperReady
              ? 'Cetak dikirim ke Epson Print Service.'
              : '⚠️ Cetak dikirim, TAPI Auto-Print Helper mati — dialog cetak '
                  'perlu ditekan manual. Aktifkan di Accessibility → '
                  'SnapTechBooth Auto Print.',
          printerName: 'Epson L8050',
          isDirect: false,
        );
      }

      return PrintJobResult(
        isSuccess: false,
        message: 'Gagal mencetak. IPP: ${lastIppFailure ?? "tidak dicoba"}. '
            'Fallback Print Service juga gagal.',
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
    lastPrintWasSilent = false;
    lastIppFailure = null;

    try {
      // ── WINDOWS: halaman uji dibentuk langsung oleh backend ───────────────
      if (Platform.isWindows) {
        // Halaman uji WAJIB memakai kompensasi yang sedang disetel — inilah
        // alat untuk mencari angkanya. Tanpa ini, operator mengubah nilai dan
        // tidak melihat perubahan apa pun.
        final unit = await getMarginUnit();
        final toMm = unit == 'inch' ? 25.4 : 1.0;
        final compX = (await getMarginHorizontal()) * toMm;
        final compY = (await getMarginVertical()) * toMm;
        debugPrint('🧭 [TestPrint] Kompensasi terbaca: H=$compX mm, V=$compY mm');

        final out = await WindowsPrinterBackend.printTestPage(
          compensationXmm: compX,
          compensationYmm: compY,
        );
        lastPrintWasSilent = out.isSuccess;
        return PrintJobResult(
          isSuccess: out.isSuccess,
          message: out.message,
          printerName: out.printerName ?? 'Epson L8050',
          isDirect: true,
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

      // ── Jalur 1: IPP langsung (silent) ──
      if (pngBytes != null) {
        final ipp = await _printViaIpp(
          imageBytes: pngBytes,
          jobName: 'Test_Page',
          copies: 1,
        );
        if (ipp != null) {
          if (ipp.isSuccess) {
            lastPrintWasSilent = true;
            return ipp;
          }
          lastIppFailure = ipp.message;
          debugPrint('⚠️ Test print IPP gagal, fallback ke PrintManager: ${ipp.message}');
        }
      }

      if (await getStrictSilent()) {
        return PrintJobResult(
          isSuccess: false,
          message: 'Mode Silent Ketat aktif — dialog cetak sengaja tidak dibuka. '
              'IPP gagal: ${lastIppFailure ?? "jalur IPP dimatikan"}',
          printerName: 'Epson L8050',
        );
      }

      // ── Jalur 2: fallback PrintManager ──
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

/// Pastikan byte yang dikirim benar-benar JPEG.
///
/// Hasil render backend bisa berupa PNG; sebagian printer hanya menerima
/// `image/jpeg`. Mengirim PNG dengan label JPEG membuat printer menolak job
/// (client-error-document-format-error) atau mencetak sampah.
Uint8List _ensureJpegBytes(Uint8List bytes) {
  final isJpeg = bytes.length > 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  if (isJpeg) return bytes;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes; // biarkan printer yang menolak
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
}

/// Bungkus foto jadi PDF satu halaman seukuran kertas foto.
///
/// Gambar di-`cover` agar memenuhi seluruh halaman — untuk borderless, area
/// yang meluber memang sengaja terpotong, bukan disisakan putih.
Future<Uint8List> _buildPhotoPdf(Map<String, dynamic> params) async {
  final imageBytes = params['imageBytes'] as Uint8List;
  final pageWidthInch = (params['pageWidthInch'] as num?)?.toDouble() ?? 4.0;
  final marginHorizMm = (params['marginHorizMm'] as num?)?.toDouble() ?? 0.0;
  final marginVertMm = (params['marginVertMm'] as num?)?.toDouble() ?? 0.0;

  const mmToPt = 2.83465;
  final pageFormat = PdfPageFormat(
    pageWidthInch * PdfPageFormat.inch,
    6.0 * PdfPageFormat.inch,
    marginAll: 0,
  );

  final doc = pw.Document();
  final image = pw.MemoryImage(imageBytes);

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          horizontal: marginHorizMm * mmToPt,
          vertical: marginVertMm * mmToPt,
        ),
        child: pw.Image(image, fit: pw.BoxFit.cover),
      ),
    ),
  );

  return doc.save();
}


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
