import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'app_exception.dart';

/// Maps raw exceptions (Dio, IO, etc.) to typed [AppException]s
/// and provides user-friendly messages in Indonesian.
final class ErrorHandler {
  ErrorHandler._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 2, errorMethodCount: 5),
  );

  /// Convert any thrown [error] into a typed [AppException].
  static AppException handle(Object error, [StackTrace? stackTrace]) {
    _logger.e('ErrorHandler caught', error: error, stackTrace: stackTrace);

    if (error is AppException) return error;

    if (error is DioException) return _handleDio(error);

    if (error is SocketException) {
      return const ConnectionException();
    }

    if (error is HttpException) {
      return NetworkException(message: error.message, cause: error);
    }

    return UnknownException(cause: error);
  }

  static AppException _handleDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(cause: e);

      case DioExceptionType.connectionError:
        return const ConnectionException();

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final message = _extractMessage(data) ?? _messageForStatus(statusCode);
        return ServerException(
          message: message,
          statusCode: statusCode,
          cause: e,
        );

      case DioExceptionType.cancel:
        return NetworkException(
          message: 'Permintaan dibatalkan',
          cause: e,
        );

      case DioExceptionType.unknown:
      default:
        if (e.error is SocketException) {
          return const ConnectionException();
        }
        return NetworkException(
          message: 'Koneksi bermasalah. Periksa jaringan Anda.',
          cause: e,
        );
    }
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return (data['message'] as String?) ??
          (data['error'] as String?);
    }
    return null;
  }

  static String _messageForStatus(int? code) {
    return switch (code) {
      400 => 'Permintaan tidak valid',
      401 => 'Tidak terautentikasi',
      403 => 'Akses ditolak',
      404 => 'Data tidak ditemukan',
      422 => 'Data tidak valid',
      429 => 'Terlalu banyak permintaan. Tunggu sebentar.',
      500 => 'Server error. Hubungi administrator.',
      503 => 'Server sedang tidak tersedia',
      _ => 'Terjadi kesalahan (kode: $code)',
    };
  }

  /// Returns a short, user-friendly string for display in the UI.
  static String toUserMessage(AppException e) {
    return switch (e) {
      ConnectionException() =>
        'Tidak ada internet. Periksa koneksi WiFi.',
      TimeoutException() =>
        'Koneksi lambat. Coba lagi.',
      ServerException(statusCode: final c) when c == 503 =>
        'Server sedang maintenance. Coba beberapa saat lagi.',
      ServerException() => e.message,
      NetworkException() => 'Koneksi bermasalah. Coba lagi.',
      CameraDisconnectedException() =>
        'Kamera tidak terhubung. Periksa kabel USB.',
      CameraCapturedException() => 'Gagal mengambil foto. Coba lagi.',
      CameraException() => e.message,
      PrinterOfflineException() =>
        'Printer offline. Hubungi operator.',
      PrinterPaperException() =>
        'Kertas habis. Hubungi operator.',
      PrinterException() => e.message,
      PrinterErrorException() => e.message,
      StorageFullException() =>
        'Penyimpanan penuh. Hubungi operator.',
      UploadException() =>
        'Gagal upload foto. Periksa koneksi.',
      StorageException() => e.message,
      PaymentFailedException() =>
        'Pembayaran gagal. Silakan coba lagi.',
      PaymentPendingException() =>
        'Pembayaran sedang diproses...',
      PaymentException() => e.message,
      SessionExpiredException() =>
        'Sesi habis. Mulai ulang dari awal.',
      SessionNotFoundException() => 'Sesi tidak ditemukan.',
      ValidationException(field: final f) =>
        f != null ? 'Field $f: ${e.message}' : e.message,
      GenerationException() => e.message,
      UnknownException() => 'Terjadi kesalahan. Coba lagi.',
      _ => e.message,
    };
  }
}
