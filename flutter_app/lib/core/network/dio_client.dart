import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../services/error_logger.dart';

/// Singleton Dio HTTP client with auth, logging, and retry interceptors.
final class DioClient {
  DioClient._internal();

  static final DioClient _instance = DioClient._internal();

  static DioClient get instance => _instance;

  late final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  final _logger = Logger();

  bool _initialized = false;

  void initialize({bool isProduction = false}) {
    if (_initialized) return;
    _initialized = true;

    final baseUrl = isProduction
        ? AppConstants.apiBaseUrlProd
        : AppConstants.apiBaseUrlDev;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiReceiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-App-Version': AppConstants.appVersion,
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_secureStorage),
      _RetryInterceptor(_dio, maxRetries: AppConstants.apiMaxRetries),
      if (!isProduction) _LoggingInterceptor(_logger),
    ]);
  }

  Dio get dio {
    assert(_initialized, 'DioClient must be initialized before use.');
    return _dio;
  }

  /// Convenience wrapper that maps Dio/network errors to [AppException].
  Future<Response<T>> safeRequest<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } catch (e, st) {
      throw ErrorHandler.handle(e, st);
    }
  }
}

// ── Auth Interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token =
        await _storage.read(key: AppConstants.secureKeyAuthToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired — clear it
      _storage.delete(key: AppConstants.secureKeyAuthToken);
    }
    handler.next(err);
  }
}

// ── Retry Interceptor ─────────────────────────────────────────────────────────

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio, {required this.maxRetries});

  final Dio _dio;
  final int maxRetries;

  static const _retryKey = '_retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retryCount =
        (err.requestOptions.extra[_retryKey] as int?) ?? 0;

    final shouldRetry = retryCount < maxRetries &&
        _isRetryable(err) &&
        err.requestOptions.method == 'GET';

    if (shouldRetry) {
      err.requestOptions.extra[_retryKey] = retryCount + 1;
      await Future<void>.delayed(
        Duration(seconds: (retryCount + 1) * 2),
      );
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // Fall through to handler.next on repeated failure
      }
    }

    handler.next(err);
  }

  bool _isRetryable(DioException err) {
    return switch (err.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse =>
        err.response?.statusCode == 503 ||
            err.response?.statusCode == 502,
      _ => false,
    };
  }
}

// ── Logging Interceptor ───────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  _LoggingInterceptor(this._logger);

  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d(
      '→ ${options.method} ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Body: ${options.data}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d(
      '← ${response.statusCode} ${response.requestOptions.uri}\n'
      'Body: ${response.data}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✗ ${err.requestOptions.method} ${err.requestOptions.uri}\n'
      'Status: ${err.response?.statusCode}\n'
      'Error: ${err.message}',
    );

    // Skip logging calls to /logs to prevent recursive loop
    if (!err.requestOptions.path.contains('/logs')) {
      ErrorLogger.instance.logNetworkError(
        endpoint: '${err.requestOptions.method} ${err.requestOptions.path}',
        message: err.message ?? 'Unknown network failure',
        statusCode: err.response?.statusCode,
        extra: {
          'type': err.type.name,
          'responseData': err.response?.data,
        },
        stackTrace: err.stackTrace,
      );
    }

    handler.next(err);
  }
}
