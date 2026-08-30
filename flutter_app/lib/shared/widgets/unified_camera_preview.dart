import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:flutter_uvc_camera/flutter_uvc_camera.dart";
import "../../core/services/uvc_camera_service.dart";

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
      // UVCCameraView selalu di-render agar PlatformView Android sudah
      // ter-attach sebelum openUVCCamera() dipanggil.
      child = UVCCameraView(
        cameraController: UvcCameraService.instance.controller,
        width: double.infinity,
        height: double.infinity,
      );
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

