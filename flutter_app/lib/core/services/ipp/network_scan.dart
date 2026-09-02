import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ipp_client.dart';

/// Satu alamat IPv4 milik tablet, beserta nama interface-nya.
///
/// Nama interface penting untuk diagnosa topologi:
/// - `wlan0`  → Wi-Fi biasa (join router)
/// - `p2p0` / `p2p-wlan0-*` → Wi-Fi Direct (P2P)
/// - `rndis0` / `eth0` → tethering USB atau adapter ethernet
class LocalAddress {
  final String interfaceName;
  final String ip;

  const LocalAddress(this.interfaceName, this.ip);

  /// Tiga oktet pertama, mis. `192.168.1`.
  String? get subnetPrefix {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  bool get isWifiDirect =>
      interfaceName.startsWith('p2p') || ip.startsWith('192.168.49.');

  @override
  String toString() => '$interfaceName: $ip';
}

/// Hasil temuan satu host yang membuka port printer.
class FoundPrinter {
  final String ip;
  final List<int> openPorts;
  final String? makeAndModel;
  final bool ippAnswered;

  const FoundPrinter({
    required this.ip,
    required this.openPorts,
    this.makeAndModel,
    this.ippAnswered = false,
  });
}

/// Diagnosa jaringan untuk jalur cetak IPP.
///
/// Dibuat karena kegagalan "printer tidak terjangkau" punya banyak sebab yang
/// tidak bisa dibedakan dari pesan error saja: IP salah, tablet dan printer
/// beda subnet, printer belum join Wi-Fi, atau IPP-nya memang tertutup.
class NetworkScan {
  NetworkScan._();

  /// Port yang relevan untuk printer Epson.
  static const Map<int, String> knownPorts = {
    631: 'IPP (jalur silent print)',
    80: 'HTTP (web config printer)',
    443: 'HTTPS',
    9100: 'RAW / JetDirect',
    515: 'LPD',
    3289: 'Epson Discovery',
  };

  /// Port yang menandakan sebuah host kemungkinan printer.
  ///
  /// 443 ikut disertakan karena sebagian Epson mematikan IPP polos di 631 dan
  /// hanya melayani IPPS di 443. Tanpa ini, printer yang siap cetak justru
  /// terlewat oleh pemindaian.
  static const List<int> printerHintPorts = [631, 443, 9100, 515];

  // ─── Alamat lokal tablet ──────────────────────────────────────────────────

  /// Daftar IPv4 milik tablet, tanpa loopback.
  static Future<List<LocalAddress>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      final out = <LocalAddress>[];
      for (final i in interfaces) {
        for (final a in i.addresses) {
          out.add(LocalAddress(i.name, a.address));
        }
      }
      return out;
    } catch (e) {
      debugPrint('NetworkScan.localAddresses error: $e');
      return const [];
    }
  }

  // ─── Cek port satu host ───────────────────────────────────────────────────

  static Future<bool> _isPortOpen(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 600),
  }) async {
    try {
      final s = await Socket.connect(ip, port, timeout: timeout);
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Periksa port-port printer pada satu IP. Mengembalikan port → terbuka.
  static Future<Map<int, bool>> checkPorts(
    String ip, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    final ports = knownPorts.keys.toList();
    final results = await Future.wait(
      ports.map((p) => _isPortOpen(ip, p, timeout: timeout)),
    );
    return Map.fromIterables(ports, results);
  }

  // ─── Pindai subnet ────────────────────────────────────────────────────────

  /// Pindai seluruh /24 dari [subnetPrefix] mencari host yang membuka port
  /// printer, lalu konfirmasi lewat IPP untuk mengambil merk/model.
  ///
  /// Timeout per host sengaja pendek; host yang tidak ada akan langsung
  /// menolak koneksi, bukan menunggu sampai timeout.
  static Future<List<FoundPrinter>> scanSubnet({
    required String subnetPrefix,
    Duration hostTimeout = const Duration(milliseconds: 500),
    int concurrency = 40,
    void Function(int done, int total)? onProgress,
  }) async {
    final candidates = <String>[
      for (var i = 1; i <= 254; i++) '$subnetPrefix.$i',
    ];

    final hits = <String, List<int>>{};
    var done = 0;

    for (var start = 0; start < candidates.length; start += concurrency) {
      final chunk = candidates.skip(start).take(concurrency).toList();

      await Future.wait(chunk.map((ip) async {
        for (final port in printerHintPorts) {
          final open = await _isPortOpen(ip, port, timeout: hostTimeout);
          if (open) {
            hits.putIfAbsent(ip, () => <int>[]).add(port);
          }
        }
        done++;
      }));

      onProgress?.call(done, candidates.length);
    }

    // Konfirmasi via IPP untuk host yang membuka 631.
    final found = <FoundPrinter>[];
    for (final entry in hits.entries) {
      String? model;
      var ippOk = false;
      if (entry.value.contains(631) || entry.value.contains(443)) {
        try {
          final info = await IppClient.getPrinterAttributes(
            ip: entry.key,
            timeout: const Duration(seconds: 4),
          );
          ippOk = info.workingPath != null;
          model = info.makeAndModel;
        } catch (_) {}
      }
      found.add(FoundPrinter(
        ip: entry.key,
        openPorts: entry.value..sort(),
        makeAndModel: model,
        ippAnswered: ippOk,
      ));
    }

    found.sort((a, b) {
      if (a.ippAnswered != b.ippAnswered) return a.ippAnswered ? -1 : 1;
      return a.ip.compareTo(b.ip);
    });

    debugPrint('🔎 Scan $subnetPrefix.0/24 selesai — ${found.length} kandidat printer');
    return found;
  }

  /// Pindai semua subnet yang tablet punya (wlan0, p2p0, dst).
  static Future<List<FoundPrinter>> scanAllLocalSubnets({
    void Function(String subnet, int done, int total)? onProgress,
  }) async {
    final addrs = await localAddresses();
    final prefixes = <String>{};
    for (final a in addrs) {
      final p = a.subnetPrefix;
      if (p != null) prefixes.add(p);
    }

    final all = <FoundPrinter>[];
    for (final prefix in prefixes) {
      final r = await scanSubnet(
        subnetPrefix: prefix,
        onProgress: (d, t) => onProgress?.call(prefix, d, t),
      );
      all.addAll(r);
    }
    return all;
  }
}
