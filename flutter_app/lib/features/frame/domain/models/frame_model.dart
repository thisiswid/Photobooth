class FrameModel {
  final int id;
  final String name;
  final String? assetUrl;
  final int poseCount;

  const FrameModel({
    required this.id,
    required this.name,
    this.assetUrl,
    this.poseCount = 4,
  });

  factory FrameModel.fromJson(Map<String, dynamic> json) {
    return FrameModel(
      id: json['id'] as int,
      name: json['name'] as String,
      assetUrl: json['asset_url'] as String?,
      poseCount: json['pose_count'] as int? ?? 4,
    );
  }

  /// Full URL for the frame asset image.
  /// The backend stores relative paths like 'frames/strip_klasik.png',
  /// which need to be prefixed with the storage URL.
  String? get fullAssetUrl {
    if (assetUrl == null || assetUrl!.isEmpty) return null;
    // For dev: http://10.0.2.2:8000/storage/frames/strip_klasik.png
    // The base URL is determined at runtime from DioClient
    return assetUrl;
  }
}
