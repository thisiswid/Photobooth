import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Centralized Error Logger & Diagnostics service for Photobooth client.
/// Automatically collects and reports network, camera, payment, and data fetch errors to backend.
class ErrorLogger {
  ErrorLogger._();
  static final ErrorLogger instance = ErrorLogger._();

  // Deduplication cache to prevent log flooding
  final Map<String, DateTime> _recentErrors = {};

  /// Log network & connection errors (No internet, timeout, connection refused, 500 error).
  Future<void> logNetworkError({
    required String endpoint,
    required String message,
    int? statusCode,
    Map<String, dynamic>? extra,
    StackTrace? stackTrace,
  }) async {
    final title = statusCode != null
        ? 'Network Error HTTP $statusCode ($endpoint)'
        : 'Network Connection Failed ($endpoint)';

    await _reportLog(
      category: 'network',
      level: statusCode != null && statusCode >= 500 ? 'critical' : 'error',
      title: title,
      message: message,
      context: {
        'endpoint': endpoint,
        'status_code': statusCode,
        ...?extra,
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log payment failures and cancelled attempts.
  Future<void> logPaymentError({
    required String reason,
    required int amount,
    Map<String, dynamic>? extra,
  }) async {
    await _reportLog(
      category: 'payment',
      level: 'error',
      title: 'Pembayaran Gagal / Dibatalkan (Rp $amount)',
      message: reason,
      context: {
        'amount': amount,
        ...?extra,
      },
    );
  }

  /// Log camera initialization or capture failures.
  Future<void> logCameraError({
    required String message,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    await _reportLog(
      category: 'camera',
      level: 'critical',
      title: 'Masalah Hardware / Software Kamera',
      message: message,
      context: extra,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log failed data fetching (frames, filters, screen configs).
  Future<void> logDataFetchError({
    required String resource,
    required String message,
    StackTrace? stackTrace,
  }) async {
    await _reportLog(
      category: 'api_fetch',
      level: 'warning',
      title: 'Gagal Mengambil Data $resource',
      message: message,
      context: {'resource': resource},
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log retry button taps and user recovery attempts.
  Future<void> logRetryAttempt({
    required String action,
    required int attempt,
    required String reason,
  }) async {
    await _reportLog(
      category: 'system',
      level: 'info',
      title: 'Percobaan Ulang ($action #$attempt)',
      message: 'Pengguna menekan coba lagi karena: $reason',
      context: {
        'action': action,
        'attempt': attempt,
        'reason': reason,
      },
    );
  }

  /// Send error log payload to backend API asynchronously.
  Future<void> _reportLog({
    required String category,
    required String level,
    required String title,
    required String message,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) async {
    // 1. Log locally to debug console
    debugPrint('🚨 [ErrorLogger:$category] $title — $message');

    // 2. Throttle duplicates within 3 seconds
    final cacheKey = '$category:$title';
    final now = DateTime.now();
    if (_recentErrors.containsKey(cacheKey)) {
      final lastTime = _recentErrors[cacheKey]!;
      if (now.difference(lastTime).inSeconds < 3) {
        return; // Skip duplicate burst
      }
    }
    _recentErrors[cacheKey] = now;

    // 3. Post to Laravel Backend /api/logs using native dart:io HttpClient
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrlDev}/logs');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');

      final body = jsonEncode({
        'device_id': 'Tablet-Photobooth-1',
        'event_id': 1,
        'category': category,
        'level': level,
        'title': title,
        'message': message,
        'context': context,
        'stack_trace': stackTrace,
      });

      request.write(body);
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Fail silently to prevent recursive errors if backend is completely unreachable
    }
  }
}
