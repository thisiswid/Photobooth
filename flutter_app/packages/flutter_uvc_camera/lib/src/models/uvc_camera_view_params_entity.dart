part of flutter_uvc_camera;

/// 自定义参数 可空  Custom parameters can be empty
///
/// PATCHED (SnapTechBooth):
/// Upstream tidak pernah mengirim previewWidth/previewHeight ke sisi Android,
/// padahal `CameraConfigManager.updateFromParams()` membacanya. Akibatnya
/// resolusi selalu jatuh ke default 640x480 (4:3) — capture card HDMI yang
/// mampu 1920x1080 (16:9) tetap dipaksa 4:3, preview jadi salah rasio dan
/// hasil foto hanya 0.3 MP. Field di bawah menutup celah itu.
class UVCCameraViewParamsEntity {
  /**
   *  if give custom minFps or maxFps or unsupported preview size
   *  set preview possible will fail
   *  **/
  /// camera preview min fps  10
  final int? minFps;

  /// camera preview max fps  60
  final int? maxFps;

  /// camera preview frame format 1 (MJPEG) or 0 (YUV)
  /// DEFAULT 1(MJPEG)  If preview fails and the screen goes black, please try switching to 0
  final int? frameFormat;

  ///  DEFAULT_BANDWIDTH = 1
  final double? bandwidthFactor;

  /// Lebar preview yang diminta ke perangkat UVC (default plugin: 640).
  final int? previewWidth;

  /// Tinggi preview yang diminta ke perangkat UVC (default plugin: 480).
  final int? previewHeight;

  /// Bila false, TextureView native mengisi penuh kotaknya (tanpa letterbox
  /// internal), sehingga rasio bisa dikendalikan dari sisi Flutter.
  final bool? aspectRatioShow;

  const UVCCameraViewParamsEntity({
    this.minFps = 10,
    this.maxFps = 60,
    this.bandwidthFactor = 1.0,
    this.frameFormat = 1,
    this.previewWidth,
    this.previewHeight,
    this.aspectRatioShow,
  });

  Map<String, dynamic> toMap() {
    return {
      "minFps": minFps,
      "maxFps": maxFps,
      "frameFormat": frameFormat,
      "bandwidthFactor": bandwidthFactor,
      if (previewWidth != null) "previewWidth": previewWidth,
      if (previewHeight != null) "previewHeight": previewHeight,
      if (aspectRatioShow != null) "aspectRatioShow": aspectRatioShow,
    };
  }
}
