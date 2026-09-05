import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Hasil satu jepretan lewat `sony_camera_helper.exe`.
class SonyHelperCapture {
  const SonyHelperCapture({
    required this.file,
    required this.width,
    required this.height,
    required this.bytes,
    required this.cameraFilename,
    required this.afWaitMs,
    required this.fileWaitMs,
    required this.elapsedMs,
    required this.afTimedOut,
    required this.staleDiscarded,
    required this.extraDiscarded,
  });

  final File file;
  final int width;
  final int height;
  final int bytes;
  final String cameraFilename;
  final int afWaitMs;
  final int fileWaitMs;
  final int elapsedMs;
  final bool afTimedOut;
  final int staleDiscarded;
  final int extraDiscarded;

  double get megapixels => (width * height) / 1000000.0;

  /// Foto sensor sungguhan, bukan frame HDMI 1080p yang menyamar.
  ///
  /// Ambang 6 MP dipilih jauh di atas 1920x1080 (2,07 MP) tapi di bawah semua
  /// mode foto ZV-E10 (paling kecil 4:3 5328x4000 = 21,3 MP; APS-C crop pun
  /// masih belasan MP). Tujuannya sama dengan `looksLikeSensorPhoto` di jalur
  /// Android: menolak diam-diam turun kualitas.
  bool get looksLikeSensorPhoto => width * height >= 6000000;

  String get dimensionLabel =>
      '${width}x$height (${megapixels.toStringAsFixed(1)} MP)';
}

/// Klien untuk `sony_camera_helper.exe` — proses terpisah yang mengendalikan
/// Sony ZV-E10 lewat Camera Control PTP.
///
/// Kenapa lewat proses terpisah dan socket, bukan FFI atau plugin:
/// lapisan WIA/COM bisa menggantung pada level driver. Kalau itu terjadi di
/// dalam proses Flutter, seluruh kiosk ikut membeku di tengah sesi pelanggan.
/// Sebagai proses anak, kegagalannya terisolasi: socket menolak, helper bisa
/// dimatikan dan dijalankan ulang, dan sesi pelanggan tetap hidup.
///
/// Lihat `tools/sony_camera_helper/README.md` untuk protokolnya.
class SonyCameraHelperClient {
  SonyCameraHelperClient._();
  static final SonyCameraHelperClient instance = SonyCameraHelperClient._();

  static const int defaultPort = 45455;

  /// Diisi dari Hidden Settings bila helper diletakkan di lokasi tidak biasa.
  static String? overrideExecutablePath;

  Process? _process;
  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  final Queue<Completer<Map<String, dynamic>>> _pending =
      Queue<Completer<Map<String, dynamic>>>();
  String _rxBuffer = '';

  /// Perintah dijalankan berurutan: helper melayani satu perintah pada satu
  /// waktu, dan balasannya dicocokkan berdasarkan urutan.
  Future<void> _queue = Future<void>.value();

  int _port = defaultPort;
  bool _cameraConnected = false;
  String _lastError = '';
  String? _outputDir;

  bool get isProcessRunning => _process != null;
  bool get isSocketOpen => _socket != null;
  bool get isCameraConnected => _cameraConnected;
  String get lastError => _lastError;
  int get port => _port;

  // ── Menemukan executable ────────────────────────────────────────────────

  /// Urutan pencarian: override manual, lalu di samping .exe aplikasi (itu
  /// yang dipakai installer C7), lalu hasil build dev di dalam repo.
  static List<String> candidatePaths() {
    final paths = <String>[];
    final override = overrideExecutablePath;
    if (override != null && override.trim().isNotEmpty) paths.add(override.trim());

    try {
      final appDir = File(Platform.resolvedExecutable).parent;
      paths.add('${appDir.path}\\sony_camera_helper.exe');
      paths.add('${appDir.path}\\helper\\sony_camera_helper.exe');

      // Saat `flutter run`, .exe ada di
      //   <repo>\flutter_app\build\windows\x64\runner\Debug\
      // sedangkan helper ada di <repo>\tools\sony_camera_helper\build\...
      var dir = appDir;
      for (var i = 0; i < 8 && dir.parent.path != dir.path; i++) {
        final candidate = Directory(
          '${dir.path}\\tools\\sony_camera_helper\\build',
        );
        if (candidate.existsSync()) {
          paths.add('${candidate.path}\\Release\\sony_camera_helper.exe');
          paths.add('${candidate.path}\\cl\\sony_camera_helper.exe');
          break;
        }
        dir = dir.parent;
      }
    } catch (_) {
      // Pencarian path tidak boleh menjatuhkan aplikasi.
    }
    return paths;
  }

  static String? resolveExecutable() {
    for (final p in candidatePaths()) {
      try {
        if (File(p).existsSync()) return p;
      } catch (_) {}
    }
    return null;
  }

  /// True bila helper terpasang. Tidak menjalankan apa pun.
  static bool get isInstalled => Platform.isWindows && resolveExecutable() != null;

  // ── Siklus hidup proses ─────────────────────────────────────────────────

  /// Jalankan helper dan sambungkan socket-nya. Aman dipanggil berulang.
  Future<bool> start({int? port, String? outputDir}) async {
    if (!Platform.isWindows) {
      _lastError = 'Helper kamera Sony hanya tersedia di Windows.';
      return false;
    }
    if (_socket != null) return true;

    _port = port ?? _port;
    _outputDir = outputDir ?? _outputDir;

    final exe = resolveExecutable();
    if (exe == null) {
      _lastError = 'sony_camera_helper.exe tidak ditemukan. '
          'Dicari di: ${candidatePaths().join(" | ")}';
      debugPrint('⚠️ [SonyHelper] $_lastError');
      return false;
    }

    if (_process == null) {
      final args = <String>[
        '--serve',
        '--port', '$_port',
        // Kalau aplikasi kiosk mati — termasuk saat crash — helper ikut keluar.
        // Helper yatim tetap memegang kamera, dan aplikasi berikutnya gagal
        // dengan WIA_ERROR_BUSY sampai kamera dicabut-colok.
        '--parent-pid', '$pid',
        if (_outputDir != null) ...['--out-dir', _outputDir!],
      ];
      try {
        debugPrint('🚀 [SonyHelper] Menjalankan $exe ${args.join(" ")}');
        _process = await Process.start(exe, args, workingDirectory: File(exe).parent.path);
      } catch (e) {
        _lastError = 'Gagal menjalankan helper: $e';
        debugPrint('❌ [SonyHelper] $_lastError');
        return false;
      }

      // Tunggu baris kesiapan dari helper, bukan menebak dengan delay.
      final ready = Completer<bool>();
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          debugPrint('📤 [SonyHelper] $line');
          if (!ready.isCompleted && line.contains('"event":"listening"')) {
            ready.complete(true);
          }
        },
        onDone: () {
          if (!ready.isCompleted) ready.complete(false);
        },
      );
      _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) => debugPrint('📤 [SonyHelper:err] $line'),
      );
      unawaited(_process!.exitCode.then((code) {
        debugPrint('⚠️ [SonyHelper] Proses helper berhenti (exit $code)');
        _process = null;
        _teardownSocket('proses helper berhenti');
      }));

      final ok = await ready.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      if (!ok) {
        _lastError = 'Helper tidak melaporkan siap dalam 10 detik.';
        debugPrint('❌ [SonyHelper] $_lastError');
        await stop();
        return false;
      }
    }

    return _openSocket();
  }

  Future<bool> _openSocket() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _port,
        timeout: const Duration(seconds: 5),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _socketSub = socket.listen(
        _onData,
        onError: (Object e) => _teardownSocket('socket error: $e'),
        onDone: () => _teardownSocket('socket ditutup helper'),
        cancelOnError: true,
      );
      debugPrint('🔌 [SonyHelper] Socket tersambung ke 127.0.0.1:$_port');
      return true;
    } catch (e) {
      _lastError = 'Gagal menyambung ke helper di port $_port: $e';
      debugPrint('❌ [SonyHelper] $_lastError');
      return false;
    }
  }

  void _onData(List<int> data) {
    _rxBuffer += utf8.decode(data, allowMalformed: true);
    while (true) {
      final idx = _rxBuffer.indexOf('\n');
      if (idx < 0) break;
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      if (_pending.isEmpty) {
        debugPrint('⚠️ [SonyHelper] Balasan tanpa permintaan: $line');
        continue;
      }
      final completer = _pending.removeFirst();
      if (completer.isCompleted) continue;
      try {
        completer.complete(jsonDecode(line) as Map<String, dynamic>);
      } catch (e) {
        completer.complete(<String, dynamic>{
          'ok': false,
          'error': 'bad_response',
          'detail': 'balasan helper tidak bisa diurai: $e',
        });
      }
    }
  }

  void _teardownSocket(String reason) {
    if (_socket == null && _pending.isEmpty) return;
    debugPrint('🔌 [SonyHelper] Socket terputus — $reason');
    _lastError = reason;
    _cameraConnected = false;
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _rxBuffer = '';
    while (_pending.isNotEmpty) {
      final c = _pending.removeFirst();
      if (!c.isCompleted) {
        c.complete(<String, dynamic>{
          'ok': false,
          'error': 'disconnected',
          'detail': reason,
        });
      }
    }
  }

  /// Matikan helper. Dipanggil saat aplikasi ditutup.
  Future<void> stop() async {
    _teardownSocket('dihentikan aplikasi');
    final proc = _process;
    _process = null;
    if (proc != null) {
      try {
        proc.kill();
        await proc.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1);
      } catch (_) {}
    }
  }

  // ── Protokol ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _send(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final result = Completer<Map<String, dynamic>>();
    _queue = _queue.then((_) async {
      if (_socket == null) {
        result.complete(<String, dynamic>{
          'ok': false,
          'error': 'not_running',
          'detail': 'helper tidak tersambung',
        });
        return;
      }
      final completer = Completer<Map<String, dynamic>>();
      _pending.add(completer);
      try {
        _socket!.write('${jsonEncode(request)}\n');
      } catch (e) {
        _pending.remove(completer);
        result.complete(<String, dynamic>{
          'ok': false,
          'error': 'write_failed',
          'detail': '$e',
        });
        return;
      }
      final reply = await completer.future.timeout(
        timeout,
        onTimeout: () {
          // Jangan biarkan balasan yang telat mengacaukan permintaan berikutnya.
          _teardownSocket('helper tidak menjawab dalam ${timeout.inSeconds} detik');
          return <String, dynamic>{
            'ok': false,
            'error': 'timeout',
            'detail': 'helper tidak menjawab dalam ${timeout.inSeconds} detik',
          };
        },
      );
      result.complete(reply);
    });
    return result.future;
  }

  Future<bool> connectCamera() async {
    final r = await _send(
      <String, dynamic>{'cmd': 'connect'},
      timeout: const Duration(seconds: 20),
    );
    _cameraConnected = r['ok'] == true;
    if (!_cameraConnected) {
      _lastError = '${r['error']}: ${r['detail']}';
      debugPrint('❌ [SonyHelper] connect gagal — $_lastError');
    } else {
      debugPrint('✅ [SonyHelper] Kamera tersambung: ${r['device']}');
    }
    return _cameraConnected;
  }

  Future<Map<String, dynamic>> status() async {
    final r = await _send(<String, dynamic>{'cmd': 'status'});
    // Helper melaporkan connected:false begitu kamera berhenti menjawab —
    // ikuti apa adanya, jangan menebak.
    if (r.containsKey('connected')) _cameraConnected = r['connected'] == true;
    return r;
  }

  Future<void> disconnectCamera() async {
    if (_socket == null) return;
    await _send(<String, dynamic>{'cmd': 'disconnect'});
    _cameraConnected = false;
  }

  /// Kunci fokus lebih awal dan TAHAN, supaya saat tombol jepret tiba yang
  /// tersisa hanya S2.
  ///
  /// Dipanggil saat hitungan mundur masih berjalan. AF tetap ditunggu
  /// sungguhan — yang dipindah cuma waktunya, bukan dihilangkan.
  /// Mengembalikan true bila fokus benar-benar terkunci.
  Future<bool> prefocus({
    Duration afTimeout = const Duration(milliseconds: 1800),
  }) async {
    // Batas tunggunya sengaja lebih pendek dari sisa hitungan mundur. Perintah
    // helper dilayani satu per satu; kalau pra-fokus menunggu terlalu lama,
    // justru dia yang menahan perintah capture. Saat batas ini lewat helper
    // TETAP menahan S1, jadi capture melanjutkan penantian AF dari titik itu.
    final r = await _send(
      <String, dynamic>{
        'cmd': 'prefocus',
        'af_timeout_ms': afTimeout.inMilliseconds,
      },
      timeout: afTimeout + const Duration(seconds: 5),
    );
    final ok = r['ok'] == true;
    if (ok) {
      debugPrint('🎯 [SonyHelper] Fokus terkunci lebih awal '
          '(${r['af_label']}, ${r['af_wait_ms']} ms)');
    } else {
      // Bukan kegagalan fatal: capture nanti akan menunggu AF sendiri.
      debugPrint('⚠️ [SonyHelper] Pra-fokus belum mengunci: '
          '${r['error']} (${r['af_label']})');
    }
    return ok;
  }

  /// Lepas fokus tanpa menjepret, mis. saat sesi dibatalkan.
  Future<void> releaseFocus() async {
    if (_socket == null) return;
    await _send(<String, dynamic>{'cmd': 'release_focus'});
  }

  /// Ambil satu foto. Mengembalikan null bila gagal — [lastError] berisi
  /// alasannya. TIDAK PERNAH mengembalikan hasil pengganti.
  Future<SonyHelperCapture?> capture({
    String? path,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final r = await _send(
      <String, dynamic>{'cmd': 'capture', if (path != null) 'path': path},
      timeout: timeout,
    );

    if (r['ok'] != true) {
      _lastError = '${r['error']}: ${r['detail'] ?? ''}';
      if (r['error'] == 'not_connected' ||
          r['error'] == 'disconnected' ||
          r['error'] == 'status_read_failed') {
        _cameraConnected = false;
      }
      debugPrint('❌ [SonyHelper] capture gagal — $_lastError');
      return null;
    }

    final filePath = r['path'] as String?;
    if (filePath == null) {
      _lastError = 'helper melaporkan sukses tanpa path berkas';
      return null;
    }
    final file = File(filePath);
    if (!file.existsSync()) {
      _lastError = 'helper melaporkan sukses tapi berkas tidak ada: $filePath';
      debugPrint('❌ [SonyHelper] $_lastError');
      return null;
    }

    final capture = SonyHelperCapture(
      file: file,
      width: (r['width'] as num?)?.toInt() ?? 0,
      height: (r['height'] as num?)?.toInt() ?? 0,
      bytes: (r['bytes'] as num?)?.toInt() ?? file.lengthSync(),
      cameraFilename: (r['camera_filename'] as String?) ?? '',
      afWaitMs: (r['af_wait_ms'] as num?)?.toInt() ?? 0,
      fileWaitMs: (r['file_wait_ms'] as num?)?.toInt() ?? 0,
      elapsedMs: (r['elapsed_ms'] as num?)?.toInt() ?? 0,
      afTimedOut: r['af_timed_out'] == true,
      staleDiscarded: (r['stale_discarded'] as num?)?.toInt() ?? 0,
      extraDiscarded: (r['extra_discarded'] as num?)?.toInt() ?? 0,
    );

    if (!capture.looksLikeSensorPhoto) {
      _lastError = 'resolusi ${capture.dimensionLabel} terlalu kecil untuk '
          'foto sensor — ditolak';
      debugPrint('❌ [SonyHelper] $_lastError');
      return null;
    }

    debugPrint('📸 [SonyHelper] ✅ ${capture.dimensionLabel}, '
        '${(capture.bytes / 1048576).toStringAsFixed(2)} MB, '
        'AF ${capture.afWaitMs} ms, transfer ${capture.fileWaitMs} ms');
    if (capture.staleDiscarded > 0 || capture.extraDiscarded > 0) {
      debugPrint('   buffer dibersihkan: ${capture.staleDiscarded} basi, '
          '${capture.extraDiscarded} sisa');
    }
    return capture;
  }
}
