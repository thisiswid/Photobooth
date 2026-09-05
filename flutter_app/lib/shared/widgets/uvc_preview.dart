import 'package:flutter/material.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';

import '../../core/services/uvc_camera_service.dart';

/// UvcPreview
///
/// Satu-satunya tempat `UVCCameraView` boleh di-render di aplikasi ini.
///
/// Kenapa harus lewat widget ini:
/// `UVCCameraViewFactory` di sisi Android hanya menyimpan SATU referensi view
/// (`private lateinit var cameraView`), yang selalu ditimpa oleh view terbaru.
/// Begitu halaman berpindah, semua perintah native beralih ke view baru dan
/// status "terbuka" milik halaman lama menjadi tidak valid. Widget ini
/// mendaftarkan generasi view ke [UvcCameraService] saat mount dan melepasnya
/// saat unmount, sehingga setiap halaman membuka ulang kamera untuk view-nya
/// sendiri (mencegah preview hitam) dan tidak ada dua view yang berebut
/// (mencegah capture menggantung).
class UvcPreview extends StatefulWidget {
  const UvcPreview({
    super.key,
    this.mirror = false,
    this.onOpenResult,
    this.autoOpen = true,
    this.previewWidth = 1920,
    this.previewHeight = 1080,
    this.background = Colors.black,
  });

  /// Cermin horizontal (mode selfie).
  final bool mirror;

  /// Dipanggil sekali setelah percobaan open selesai (berhasil atau gagal).
  final void Function(bool opened)? onOpenResult;

  /// Set false bila pemanggil ingin mengatur sendiri kapan open dilakukan.
  final bool autoOpen;

  /// Resolusi yang diminta ke capture card.
  ///
  /// Default 1920x1080 (16:9) — resolusi native HDMI-out Sony ZV-E10.
  /// Tanpa ini plugin memakai default-nya sendiri, 640x480 (4:3), sehingga
  /// preview salah rasio (terlihat "berdiri") dan foto hanya 0.3 MP.
  final int previewWidth;
  final int previewHeight;

  /// Warna area letterbox.
  final Color background;

  @override
  State<UvcPreview> createState() => _UvcPreviewState();
}

class _UvcPreviewState extends State<UvcPreview> {
  late final int _generation;

  /// Frame pertama belum tentu langsung ada. Sebelum itu, capture card
  /// menampilkan pola "no signal" (garis-garis warna seperti TV tanpa sinyal).
  /// Kita tutupi dengan layar gelap sampai kamera benar-benar terbuka.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _generation = UvcCameraService.instance.attachView();

    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Tunggu PlatformView selesai dibuat di sisi Android sebelum open.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final opened = await UvcCameraService.instance.open();
        if (!mounted) return;

        if (opened) {
          // Beri jeda singkat agar frame MJPEG pertama sudah ter-render,
          // sehingga pola "no signal" capture card tidak sempat terlihat.
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (!mounted) return;
          setState(() => _ready = true);
        }
        widget.onOpenResult?.call(opened);
      });
    } else {
      _ready = true;
    }
  }

  @override
  void dispose() {
    UvcCameraService.instance.detachView(_generation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `aspectRatioShow: false` membuat TextureView native mengisi penuh
    // kotaknya tanpa letterbox internal, sehingga rasio sepenuhnya diatur di
    // sisi Flutter oleh AspectRatio di bawah. Ini yang membuat orientasi
    // preview konsisten (selalu landscape) di panel apa pun.
    Widget view = UVCCameraView(
      cameraController: UvcCameraService.instance.controller,
      width: double.infinity,
      height: double.infinity,
      params: UVCCameraViewParamsEntity(
        previewWidth: widget.previewWidth,
        previewHeight: widget.previewHeight,
        aspectRatioShow: false,
      ),
    );

    // Kunci rasio dengan AspectRatio + Center.
    //
    // JANGAN pakai LayoutBuilder di sekitar PlatformView: LayoutBuilder
    // membangun anaknya DI DALAM fase layout, sementara AndroidView butuh
    // fase layout untuk menyiapkan surface-nya. Kombinasi itu membuat aplikasi
    // menggantung saat frame pertama (app hang tepat setelah
    // "UVCCameraController init", lalu Lost connection to device).
    //
    // JANGAN pula pakai FittedBox + SizedBox(1920x1080): itu memaksa
    // PlatformView di-layout pada 1920x1080 *logical pixel* (≈3840x2160 fisik
    // pada density 2.0) — boros GPU dan bikin
    // "surface measure size null" + "Timeout waiting for task".
    //
    // AspectRatio menghitung ukurannya murni di fase layout, tanpa membangun
    // ulang widget, dan memakai ukuran panel yang sebenarnya.
    view = Center(
      child: AspectRatio(
        aspectRatio: widget.previewWidth / widget.previewHeight,
        child: view,
      ),
    );

    if (widget.mirror) {
      view = Transform.flip(flipX: true, child: view);
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: widget.background),
          view,
          // Tirai anti "no signal": hilang begitu frame pertama siap.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _ready ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: Container(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
