import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "uvc_preview.dart";

/// Unified camera preview that renders either USB UVC HDMI stream or standard Camera2 preview.
class UnifiedCameraPreview extends StatelessWidget {
  const UnifiedCameraPreview({
    super.key,
    this.cameraController,
    this.isUvcMode = false,
    this.isMirrored = false,
    this.isInitializing = false,
  });

  final CameraController? cameraController;
  final bool isUvcMode;
  final bool isMirrored;

  /// True selagi kamera sedang dibuka. Membedakan "sedang memuat" (spinner)
  /// dari "memang tidak ada kamera" (latar diam + keterangan).
  final bool isInitializing;

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (isUvcMode) {
      // Selalu lewat UvcPreview: widget itu yang mendaftarkan generasi view ke
      // UvcCameraService dan membuka kamera untuk view-nya sendiri.
      child = const UvcPreview();
    } else if (cameraController != null && cameraController!.value.isInitialized) {
      final size = cameraController!.value.previewSize;
      final aspectRatio = size != null ? size.width / size.height : 16 / 9;
      child = Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: CameraPreview(cameraController!),
        ),
      );
    } else if (isInitializing) {
      // Kamera sedang dibuka — spinner wajar di sini.
      child = Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    } else {
      // Tidak ada kamera sama sekali.
      //
      // Sebelumnya kondisi ini menampilkan spinner selamanya, sehingga layar
      // Welcome tampak seperti aplikasi yang tidak mau terbuka. Padahal kiosk
      // HARUS tetap bisa dinavigasi tanpa kamera — misal saat kamera dicabut,
      // atau saat menyiapkan mesin sebelum hardware terpasang.
      child = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1410), Color(0xFF2A211A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 44, color: Colors.white.withValues(alpha: 0.28)),
              const SizedBox(height: 10),
              Text(
                'Kamera belum tersambung',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isMirrored) {
      return Transform.flip(flipX: true, child: child);
    }
    return child;
  }
}

