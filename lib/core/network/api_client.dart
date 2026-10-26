import 'package:dio/dio.dart';

import '../errors/failures.dart';
import 'auth_interceptor.dart';

/// Talks to the SafeVault FastAPI backend.
///
/// The backend stores the device's FCM token and sends reminder push
/// notifications (for example "Review your vault and nominees").
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                contentType: Headers.jsonContentType,
              ),
            ) {
    _dio.interceptors.add(AuthInterceptor(tokenProvider));
  }

  final Dio _dio;

  /// Exposed for tests.
  Dio get dio => _dio;

  /// Saves this phone's FCM token so the backend can send it notifications.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) =>
      _guard(() => _dio.post<dynamic>('/devices', data: {
            'token': fcmToken,
            'platform': platform,
          }));

  /// Asks the backend to send a push reminder at [remindAt].
  Future<void> scheduleReminder({
    required String title,
    required DateTime remindAt,
  }) =>
      _guard(() => _dio.post<dynamic>('/reminders', data: {
            'title': title,
            'remind_at': remindAt.toUtc().toIso8601String(),
          }));

  /// Converts network errors into a friendly [Failure].
  Future<void> _guard(Future<Response<dynamic>> Function() request) async {
    try {
      await request();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        throw const Failure('Session expired. Please sign in again.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const Failure('Could not reach the server. Check your internet.');
      }
      throw Failure('Server error${code != null ? ' ($code)' : ''}.');
    }
  }
}
