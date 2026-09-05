/// Sealed exception hierarchy for SnapTechBooth.
/// Every failure in the app maps to one of these typed exceptions
/// so the UI layer can display the right friendly message.
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

// ── Network ───────────────────────────────────────────────────────────────────

final class NetworkException extends AppException {
  const NetworkException({required super.message, super.cause, this.statusCode});
  final int? statusCode;
}

final class ConnectionException extends AppException {
  const ConnectionException({
    super.message = 'Tidak ada koneksi internet',
    super.cause,
  });
}

final class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'Koneksi timeout, coba lagi',
    super.cause,
  });
}

final class ServerException extends AppException {
  const ServerException({required super.message, super.cause, this.statusCode});
  final int? statusCode;
}

// ── Camera ────────────────────────────────────────────────────────────────────

final class CameraException extends AppException {
  const CameraException({required super.message, super.cause});
}

final class CameraDisconnectedException extends AppException {
  const CameraDisconnectedException({
    super.message = 'Kamera tidak terhubung. Periksa koneksi USB.',
    super.cause,
  });
}

final class CameraCapturedException extends AppException {
  const CameraCapturedException({
    super.message = 'Gagal mengambil foto. Coba lagi.',
    super.cause,
  });
}

// ── Printer ───────────────────────────────────────────────────────────────────

final class PrinterException extends AppException {
  const PrinterException({required super.message, super.cause});
}

final class PrinterOfflineException extends AppException {
  const PrinterOfflineException({
    super.message = 'Printer tidak tersedia. Hubungi operator.',
    super.cause,
  });
}

final class PrinterPaperException extends AppException {
  const PrinterPaperException({
    super.message = 'Kertas habis. Hubungi operator.',
    super.cause,
  });
}

final class PrinterErrorException extends AppException {
  const PrinterErrorException({required super.message, super.cause});
}

// ── Storage ───────────────────────────────────────────────────────────────────

final class StorageException extends AppException {
  const StorageException({required super.message, super.cause});
}

final class StorageFullException extends AppException {
  const StorageFullException({
    super.message = 'Penyimpanan penuh. Hubungi operator.',
    super.cause,
  });
}

final class UploadException extends AppException {
  const UploadException({
    super.message = 'Gagal mengunggah foto. Periksa koneksi internet.',
    super.cause,
  });
}

// ── Payment ───────────────────────────────────────────────────────────────────

final class PaymentException extends AppException {
  const PaymentException({required super.message, super.cause});
}

final class PaymentFailedException extends AppException {
  const PaymentFailedException({
    super.message = 'Pembayaran gagal. Silakan coba lagi.',
    super.cause,
  });
}

final class PaymentPendingException extends AppException {
  const PaymentPendingException({
    super.message = 'Pembayaran sedang diproses.',
    super.cause,
  });
}

// ── Session ───────────────────────────────────────────────────────────────────

final class SessionExpiredException extends AppException {
  const SessionExpiredException({
    super.message = 'Sesi telah berakhir.',
    super.cause,
  });
}

final class SessionNotFoundException extends AppException {
  const SessionNotFoundException({
    super.message = 'Sesi tidak ditemukan.',
    super.cause,
  });
}

// ── Validation ────────────────────────────────────────────────────────────────

final class ValidationException extends AppException {
  const ValidationException({required super.message, this.field, super.cause});
  final String? field;
}

// ── Generation ────────────────────────────────────────────────────────────────

final class GenerationException extends AppException {
  const GenerationException({required super.message, super.cause});
}

// ── Unknown ───────────────────────────────────────────────────────────────────

final class UnknownException extends AppException {
  const UnknownException({
    super.message = 'Terjadi kesalahan. Coba lagi.',
    super.cause,
  });
}
