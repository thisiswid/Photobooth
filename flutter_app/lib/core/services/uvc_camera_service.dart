import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';

class UvcCameraService {
  UvcCameraService._();
  static final UvcCameraService instance = UvcCameraService._();

  UVCCameraController? _controller;
  bool _isOpen = false;
  String? _lastError;

  UVCCameraController get controller {
    _controller ??= UVCCameraController();
    return _controller!;
  }

  bool get isOpen => _isOpen;
  String? get lastError => _lastError;

  void init() {
    final c = controller;
    c.cameraStateCallback = (state) {
      debugPrint('📹 [UvcCameraService] state callback: $state');
      if (state == UVCCameraState.opened) {
        _isOpen = true;
      } else if (state == UVCCameraState.closed || state == UVCCameraState.error) {
        _isOpen = false;
      }
    };
  }

  /// Buka UVC camera. Permission sudah harus di-request sebelum memanggil ini.
  Future<bool> open() async {
    try {
      init();
      await controller.openUVCCamera();
      debugPrint('📹 [UvcCameraService] openUVCCamera() called, polling state...');

      // Poll _isOpen dengan interval 200ms, timeout 3 detik total
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('📹 [UvcCameraService] poll $i: _isOpen=$_isOpen');
        if (_isOpen) {
          _lastError = null;
          debugPrint('✅ [UvcCameraService] Camera opened successfully');
          return true;
        }
      }

      _lastError = 'UVC camera tidak merespons setelah 3 detik';
      debugPrint('❌ [UvcCameraService] Camera open timeout');
      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('⚠️ [UvcCameraService] Gagal open UVC camera: $e');
      return false;
    }
  }

  Future<dart_io.File?> takePhoto() async {
    try {
      final path = await controller.takePicture();
      if (path != null && path.isNotEmpty) {
        final file = dart_io.File(path);
        if (file.existsSync()) {
          return file;
        }
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ [UvcCameraService] takePhoto error: $e');
      return null;
    }
  }

  void close() {
    try {
      _controller?.closeCamera();
      _isOpen = false;
    } catch (_) {}
  }

  void dispose() {
    try {
      close();
      _controller?.dispose();
      _controller = null;
    } catch (_) {}
  }
}
