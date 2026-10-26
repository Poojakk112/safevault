import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps the local_auth package (fingerprint / face unlock).
class BiometricService {
  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True if the phone has a fingerprint/face sensor or a screen lock.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the system unlock prompt. Returns true if the user passed.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock SafeVault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }
}
