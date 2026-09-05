import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'ipp_protocol.dart';

/// Ringkasan kemampuan printer hasil operasi Get-Printer-Attributes.
class IppPrinterInfo {
  final bool reachable;
  final String? makeAndModel;
  final String? state; // 3=idle, 4=processing, 5=stopped
  final String? stateLabel;
  final List<String> stateReasons;
  final List<String> documentFormats;
  final List<String> mediaSupported;
  final List<String> colorModes;
  final List<String> sidesSupported;
  final bool acceptingJobs;

  /// Path IPP yang terbukti berhasil (mis. `/ipp/print`). Dipakai ulang saat cetak.
  final String? workingPath;

  /// Port yang terbukti menjawab (631 untuk IPP, 443 untuk IPPS).
  final int? workingPort;

  /// True bila endpoint yang berhasil memakai TLS (IPPS).
  final bool workingTls;

  /// Format dokumen yang akan dipakai untuk mencetak, hasil negosiasi.
  final String? chosenFormat;

  final String? error;

  /// Dump mentah seluruh atribut untuk panel diagnostik.
  final String rawDump;

  const IppPrinterInfo({
    required this.reachable,
    this.makeAndModel,
    this.state,
    this.stateLabel,
    this.stateReasons = const [],
    this.documentFormats = const [],
    this.mediaSupported = const [],
    this.colorModes = const [],
    this.sidesSupported = const [],
    this.acceptingJobs = false,
    this.workingPath,
    this.workingPort,
    this.workingTls = false,
    this.chosenFormat,
    this.error,
    this.rawDump = '',
  });

  /// Printer siap menerima job cetak silent.
  bool get isPrintable =>
      reachable && workingPath != null && chosenFormat != null && acceptingJobs;
}

/// Hasil satu operasi Print-Job.
class IppJobResult {
  final bool isSuccess;
  final String message;
  final int? jobId;
  final String? jobState;
  final int? statusCode;
  final String? statusLabel;

  const IppJobResult({
    required this.isSuccess,
    required this.message,
    this.jobId,
    this.jobState,
    this.statusCode,
    this.statusLabel,
  });
}

/// Klien IPP untuk cetak SILENT ke printer jaringan (AirPrint / Mopria /
/// IPP Everywhere).
///
/// Jalur ini sepenuhnya melewati Android PrintManager, sehingga:
/// - TIDAK ada dialog print preview
/// - TIDAK butuh Accessibility Service untuk menekan tombol Print
///
/// Dipakai untuk Epson L8050 yang TIDAK mengekspos IPP-over-USB (hasil probe
/// USB: hanya interface printer raw 7/1/2), sehingga jalur silent yang tersedia
/// adalah IPP lewat jaringan — baik via router maupun Wi-Fi Direct.
class IppClient {
  IppClient._();

  static const int defaultPort = 631;

  /// Urutan path yang dicoba. Epson umumnya di `/ipp/print`.
  static const List<String> candidatePaths = [
    '/ipp/print',
    '/ipp/printer',
    '/ipp',
    '/',
  ];

  /// Port IPPS (IPP over TLS). Sebagian Epson mematikan IPP polos di 631 dan
  /// hanya melayani IPPS di 443 — kondisi yang terlihat sebagai "port 631
  /// tertutup" padahal printer siap mencetak.
  static const int ippsPort = 443;

  /// Format yang bisa kita hasilkan sendiri. `image/urf` (Apple Raster) dan
  /// `image/pwg-raster` sengaja TIDAK dimasukkan karena butuh encoder raster
  /// tersendiri yang belum diimplementasikan.
  static const List<String> producibleFormats = [
    'application/pdf',
    'image/jpeg',
    'application/octet-stream',
  ];

  static int _requestCounter = 1;
  static int _nextRequestId() => _requestCounter++;

  /// Cache path yang berhasil per IP, supaya cetak berikutnya tidak
  /// mengulang percobaan 4 path.
  static final Map<String, String> _pathCache = {};

  static String _stateLabel(String? code) {
    switch (code) {
      case '3':
        return 'idle';
      case '4':
        return 'processing';
      case '5':
        return 'stopped';
      default:
        return code == null ? 'unknown' : 'state-$code';
    }
  }

  static String _jobStateLabel(int? code) {
    switch (code) {
      case 3:
        return 'pending';
      case 4:
        return 'pending-held';
      case 5:
        return 'processing';
      case 6:
        return 'processing-stopped';
      case 7:
        return 'canceled';
      case 8:
        return 'aborted';
      case 9:
        return 'completed';
      default:
        return code == null ? 'unknown' : 'job-state-$code';
    }
  }

  /// Pilih format dokumen terbaik yang didukung printer DAN bisa kita hasilkan.
  ///
  /// [preferred] adalah format sumber (mis. `image/jpeg` bila foto sudah JPEG),
  /// dipakai lebih dulu agar tidak ada konversi yang tidak perlu.
  static String? chooseFormat(List<String> supported, {String? preferred}) {
    if (supported.isEmpty) {
      // Printer tidak melaporkan daftar format — pakai PDF sebagai taruhan teraman.
      return preferred ?? 'application/pdf';
    }
    if (preferred != null &&
        supported.contains(preferred) &&
        producibleFormats.contains(preferred)) {
      return preferred;
    }
    for (final f in producibleFormats) {
      if (supported.contains(f)) return f;
    }
    return null;
  }

  // ─── Transport ────────────────────────────────────────────────────────────

  /// Kirim satu request IPP mentah dan kembalikan response yang sudah di-parse.
  static Future<IppResponse> _send({
    required String ip,
    required int port,
    required String path,
    required Uint8List body,
    bool useTls = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;

    // Sertifikat printer selalu self-signed dan tidak mungkin divalidasi rantai
    // CA-nya. Menerimanya adalah praktik standar untuk pencetakan di LAN (CUPS
    // pun begitu); risikonya terbatas pada jaringan lokal kiosk.
    client.badCertificateCallback = (cert, host, p) => true;

    try {
      final scheme = useTls ? 'https' : 'http';
      final uri = Uri.parse('\$scheme://\$ip:\$port\$path');
      final req = await client.postUrl(uri).timeout(timeout);

      req.headers.set(HttpHeaders.contentTypeHeader, 'application/ipp');
      req.headers.set(HttpHeaders.acceptHeader, 'application/ipp');
      // contentLength eksplisit — sebagian printer menolak transfer chunked.
      req.contentLength = body.length;
      req.add(body);

      final res = await req.close().timeout(timeout);

      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      final data = builder.toBytes();

      if (res.statusCode != 200) {
        throw HttpException(
          'HTTP ${res.statusCode} dari printer (${data.length} byte)',
          uri: uri,
        );
      }

      return parseIppResponse(data);
    } finally {
      client.close(force: true);
    }
  }

  // ─── Get-Printer-Attributes ───────────────────────────────────────────────

  /// Tanya kemampuan printer. Mencoba beberapa path sampai ada yang menjawab.
  static Future<IppPrinterInfo> getPrinterAttributes({
    required String ip,
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // Cek keterjangkauan dulu supaya kegagalan jaringan cepat ketahuan.
    //
    // PENTING: jangan menguji port IPP saja. Sebagian Epson mematikan IPP polos
    // di 631 dan hanya melayani IPPS di 443. Menyerah hanya karena 631 tertutup
    // membuat printer yang sebenarnya siap dilaporkan "tidak terjangkau".
    var anyOpen = false;
    final probedPorts = <int>[port, ippsPort, 80];
    for (final probePort in probedPorts) {
      try {
        final sock = await Socket.connect(ip, probePort, timeout: timeout);
        sock.destroy();
        anyOpen = true;
        break;
      } catch (_) {
        // port ini tertutup — coba berikutnya
      }
    }

    if (!anyOpen) {
      return IppPrinterInfo(
        reachable: false,
        error: 'Printer tidak menjawab di $ip pada port '
            '${probedPorts.join(", ")}. Periksa jaringan dan alamat IP.',
      );
    }

    final cached = _pathCache[ip];
    final paths = <String>[
      if (cached != null) cached,
      ...candidatePaths.where((p) => p != cached),
    ];

    // Coba IPP polos dulu, lalu IPPS. Urutan ini penting: bila keduanya hidup,
    // IPP polos lebih ringan (tanpa handshake TLS di setiap job cetak).
    final endpoints = <MapEntry<int, bool>>[
      MapEntry(port, false),
      const MapEntry(ippsPort, true),
    ];

    Object? lastError;

    for (final ep in endpoints) {
      final epPort = ep.key;
      final epTls = ep.value;

      // Lewati bila port ini jelas tertutup — hemat waktu.
      try {
        final probe = await Socket.connect(ip, epPort, timeout: const Duration(seconds: 3));
        probe.destroy();
      } catch (e) {
        lastError = 'port $epPort tertutup';
        continue;
      }

      for (final path in paths) {
      try {
        final b = IppRequestBuilder(
          operationId: IppOperation.getPrinterAttributes,
          requestId: _nextRequestId(),
        );
        b.startGroup(IppDelimiter.operationAttributes);
        b.addString(IppTag.charset, 'attributes-charset', 'utf-8');
        b.addString(IppTag.naturalLanguage, 'attributes-natural-language', 'en');
        b.addString(IppTag.uri, 'printer-uri',
            '${epTls ? "ipps" : "ipp"}://$ip:$epPort$path');
        b.addString(IppTag.nameWithoutLanguage, 'requesting-user-name', 'snaptechbooth');
        b.addStrings(IppTag.keyword, 'requested-attributes', const [
          'printer-make-and-model',
          'printer-state',
          'printer-state-reasons',
          'printer-is-accepting-jobs',
          'document-format-supported',
          'document-format-default',
          'media-supported',
          'media-default',
          'media-ready',
          'print-color-mode-supported',
          'sides-supported',
          'printer-resolution-supported',
          'printer-resolution-default',
          'print-quality-supported',
          'ipp-versions-supported',
          'operations-supported',
        ]);

        final res = await _send(
          ip: ip,
          port: epPort,
          path: path,
          body: b.finish(),
          useTls: epTls,
          timeout: timeout,
        );

        if (!res.isSuccess) {
          lastError = 'IPP ${res.statusLabel} di $path (port $epPort)';
          continue;
        }

        _pathCache[ip] = path;

        final formats = res.stringList('document-format-supported');
        final stateCode = res.firstString('printer-state');

        final dump = StringBuffer()
          ..writeln('endpoint: ${epTls ? "ipps" : "ipp"}://$ip:$epPort$path')
          ..writeln('path: $path')
          ..writeln('ipp-version: ${res.versionMajor}.${res.versionMinor}')
          ..writeln('status: ${res.statusLabel}');
        final keys = res.attributes.keys.toList()..sort();
        for (final k in keys) {
          dump.writeln('$k = ${res.attributes[k]!.join(', ')}');
        }

        return IppPrinterInfo(
          reachable: true,
          makeAndModel: res.firstString('printer-make-and-model'),
          state: stateCode,
          stateLabel: _stateLabel(stateCode),
          stateReasons: res.stringList('printer-state-reasons'),
          documentFormats: formats,
          mediaSupported: res.stringList('media-supported'),
          colorModes: res.stringList('print-color-mode-supported'),
          sidesSupported: res.stringList('sides-supported'),
          acceptingJobs: res.attributes['printer-is-accepting-jobs']?.first == true,
          workingPath: path,
          workingPort: epPort,
          workingTls: epTls,
          chosenFormat: chooseFormat(formats),
          rawDump: dump.toString().trimRight(),
        );
      } catch (e) {
        lastError = e;
        debugPrint('IPP Get-Printer-Attributes gagal di $path (port $epPort): $e');
      }
      }
    }

    return IppPrinterInfo(
      reachable: true,
      error: 'Tidak ada endpoint IPP yang menjawab (631 IPP maupun 443 IPPS). '
          'Terakhir: $lastError',
    );
  }

  // ─── Print-Job ────────────────────────────────────────────────────────────

  /// Kirim satu dokumen untuk dicetak.
  ///
  /// [documentBytes] harus SUDAH dalam [documentFormat] — konversi dilakukan
  /// pemanggil (PrinterService), bukan di sini.
  ///
  /// Bila [borderless] true, margin diminta lewat `media-col` dengan keempat
  /// margin bernilai 0. Bila false, dipakai keyword `media` biasa. Keduanya
  /// tidak boleh dikirim bersamaan — IPP menganggapnya konflik.
  static Future<IppJobResult> printJob({
    required String ip,
    required Uint8List documentBytes,
    required String documentFormat,
    int port = defaultPort,
    bool useTls = false,
    String? path,
    String jobName = 'SnapTechBooth',
    int copies = 1,
    bool borderless = true,
    String media = 'na_index-4x6_4x6in',
    int mediaWidthHundredthMm = 10160, // 4 inch
    int mediaHeightHundredthMm = 15240, // 6 inch
    int resolutionDpi = 300,
    String colorMode = 'color',
    int printQuality = 5, // 3=draft, 4=normal, 5=high
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final targetPath = path ?? _pathCache[ip] ?? candidatePaths.first;

    try {
      final b = IppRequestBuilder(
        operationId: IppOperation.printJob,
        requestId: _nextRequestId(),
      );

      // ── operation attributes ──
      b.startGroup(IppDelimiter.operationAttributes);
      b.addString(IppTag.charset, 'attributes-charset', 'utf-8');
      b.addString(IppTag.naturalLanguage, 'attributes-natural-language', 'en');
      b.addString(IppTag.uri, 'printer-uri',
          '${useTls ? "ipps" : "ipp"}://$ip:$port$targetPath');
      b.addString(IppTag.nameWithoutLanguage, 'requesting-user-name', 'snaptechbooth');
      b.addString(IppTag.nameWithoutLanguage, 'job-name', jobName);
      b.addString(IppTag.mimeMediaType, 'document-format', documentFormat);

      // ── job attributes ──
      b.startGroup(IppDelimiter.jobAttributes);
      b.addInteger(IppTag.integer, 'copies', copies);
      b.addString(IppTag.keyword, 'print-color-mode', colorMode);
      b.addInteger(IppTag.enumValue, 'print-quality', printQuality);
      b.addResolution('printer-resolution', IppResolution(resolutionDpi, resolutionDpi));

      if (borderless) {
        // Borderless = minta margin nol secara eksplisit lewat media-col.
        b.addCollection(
          'media-col',
          IppCollection({
            'media-size': MapEntry(
              IppTag.begCollection,
              IppCollection({
                'x-dimension': MapEntry(IppTag.integer, mediaWidthHundredthMm),
                'y-dimension': MapEntry(IppTag.integer, mediaHeightHundredthMm),
              }),
            ),
            'media-top-margin': const MapEntry(IppTag.integer, 0),
            'media-bottom-margin': const MapEntry(IppTag.integer, 0),
            'media-left-margin': const MapEntry(IppTag.integer, 0),
            'media-right-margin': const MapEntry(IppTag.integer, 0),
            'media-type': const MapEntry(IppTag.keyword, 'photographic-glossy'),
          }),
        );
      } else {
        b.addString(IppTag.keyword, 'media', media);
      }

      final body = b.finish(documentBytes);

      debugPrint(
        '🖨️ IPP Print-Job → ${useTls ? "ipps" : "ipp"}://$ip:$port$targetPath '
        '(format=$documentFormat, ${documentBytes.length} byte, '
        'borderless=$borderless, copies=$copies)',
      );

      final res = await _send(
        ip: ip,
        port: port,
        path: targetPath,
        body: body,
        useTls: useTls,
        timeout: timeout,
      );

      final jobId = res.firstInt('job-id');
      final jobState = _jobStateLabel(res.firstInt('job-state'));

      if (res.isSuccess) {
        _pathCache[ip] = targetPath;
        return IppJobResult(
          isSuccess: true,
          message: 'Job diterima printer (job-id: ${jobId ?? '-'}, state: $jobState)',
          jobId: jobId,
          jobState: jobState,
          statusCode: res.statusCode,
          statusLabel: res.statusLabel,
        );
      }

      return IppJobResult(
        isSuccess: false,
        message: 'Printer menolak job: ${res.statusLabel}',
        jobId: jobId,
        jobState: jobState,
        statusCode: res.statusCode,
        statusLabel: res.statusLabel,
      );
    } catch (e) {
      debugPrint('IPP Print-Job error: $e');
      return IppJobResult(
        isSuccess: false,
        message: 'Gagal mengirim job IPP ke $ip:$port$targetPath — $e',
      );
    }
  }
}
