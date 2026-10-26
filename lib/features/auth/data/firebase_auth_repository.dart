import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/failures.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
        (user) => user == null
            ? null
            : AppUser(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
              ),
      );

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ));

  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user?.updateDisplayName(name.trim());
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthFailure('Google sign-in was cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      });

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<String?> getIdToken() async => await _auth.currentUser?.getIdToken();

  /// Runs [action] and turns Firebase errors into friendly messages.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
