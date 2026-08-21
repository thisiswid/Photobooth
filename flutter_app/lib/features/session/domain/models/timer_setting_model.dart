class TimerSettingModel {
  const TimerSettingModel({
    this.name = 'Default Timer',
    this.cameraCountdownSeconds = 5,
    this.sessionTimeoutSeconds = 300,
    this.paymentTimeoutSeconds = 120,
    this.resultScreenTimeoutSeconds = 60,
    this.retakeTimeoutSeconds = 60,
    this.isActive = true,
  });

  final String name;
  final int cameraCountdownSeconds;
  final int sessionTimeoutSeconds;
  final int paymentTimeoutSeconds;
  final int resultScreenTimeoutSeconds;
  final int retakeTimeoutSeconds;
  final bool isActive;

  factory TimerSettingModel.fromJson(Map<String, dynamic> json) {
    return TimerSettingModel(
      name: json['name'] as String? ?? 'Default Timer',
      cameraCountdownSeconds: json['camera_countdown_seconds'] as int? ?? 5,
      sessionTimeoutSeconds: json['session_timeout_seconds'] as int? ?? 300,
      paymentTimeoutSeconds: json['payment_timeout_seconds'] as int? ?? 120,
      resultScreenTimeoutSeconds: json['result_screen_timeout_seconds'] as int? ?? 60,
      retakeTimeoutSeconds: json['retake_timeout_seconds'] as int? ?? 60,
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'camera_countdown_seconds': cameraCountdownSeconds,
    'session_timeout_seconds': sessionTimeoutSeconds,
    'payment_timeout_seconds': paymentTimeoutSeconds,
    'result_screen_timeout_seconds': resultScreenTimeoutSeconds,
    'retake_timeout_seconds': retakeTimeoutSeconds,
    'is_active': isActive,
  };
}
