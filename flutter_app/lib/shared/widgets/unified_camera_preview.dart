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
  });

  final CameraController? cameraController;
  final bool isUvcMode;
  final bool isMirrored;

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
    } else {
      child = Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    if (isMirrored) {
      return Transform.flip(flipX: true, child: child);
    }
    return child;
  }
}

