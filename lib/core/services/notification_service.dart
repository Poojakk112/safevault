import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../network/api_client.dart';

/// Runs when a push notification arrives while the app is closed or in the
/// background. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.messageId}');
}

/// Handles Firebase Cloud Messaging (FCM) push notifications.
///
/// Flow:
/// 1. Ask the user for notification permission.
/// 2. Get this device's FCM token.
/// 3. Send the token to our backend (POST /devices).
/// 4. The backend uses the token to send reminders through FCM.
class NotificationService {
  NotificationService({
    required ApiClient apiClient,
    FirebaseMessaging? messaging,
  })  : _api = apiClient,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _api;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refreshSub;

  /// Messages received while the app is open (shown as a SnackBar).
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  /// Returns true if notifications were enabled successfully.
  Future<bool> enable() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    final token = await _messaging.getToken();
    if (token == null) return false;
    await _api.registerDevice(fcmToken: token, platform: _platformName());

    // FCM can rotate the token; keep the backend up to date.
    await _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _api
          .registerDevice(fcmToken: newToken, platform: _platformName())
          .catchError((Object e) => debugPrint('Token refresh failed: $e'));
    });
    return true;
  }

  Future<void> disable() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    await _messaging.deleteToken();
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
