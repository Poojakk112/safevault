import 'app_user.dart';

/// What the app needs from an authentication provider.
///
/// The domain layer only knows this abstract class. The Firebase version
/// lives in the data layer, so we can swap it (or mock it in tests) easily.
abstract class AuthRepository {
  /// Emits the current user whenever they sign in or out (null = signed out).
  Stream<AppUser?> authStateChanges();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// The Firebase ID token (a JWT) used to call our backend.
  Future<String?> getIdToken();
}
