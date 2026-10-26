/// A simple error type the UI can show to the user.
///
/// The data layer catches technical exceptions (FirebaseAuthException,
/// DioException, ...) and converts them into a [Failure] with a friendly
/// message, so the presentation layer never deals with Firebase/Dio details.
class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class VaultFailure extends Failure {
  const VaultFailure(super.message);
}
