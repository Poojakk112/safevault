import 'package:dio/dio.dart';

/// Signature of a function that returns the current user's ID token (JWT).
typedef TokenProvider = Future<String?> Function();

/// Dio interceptor that adds `Authorization: Bearer <token>` to every request.
///
/// The token is the Firebase ID token (a JWT). The FastAPI backend verifies it
/// with the Firebase Admin SDK, so the backend always knows which user is
/// calling, without the app sending passwords.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);

  final TokenProvider _tokenProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
