part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Everything the UI needs to know about authentication.
final class AuthState extends Equatable {
  const AuthState._({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  /// App just started; we don't know yet if someone is signed in.
  const AuthState.unknown() : this._();

  const AuthState.authenticated(AppUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({bool? isLoading, String? errorMessage}) => AuthState._(
        status: status,
        user: user,
        isLoading: isLoading ?? this.isLoading,
        // Passing null clears the old error on purpose.
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, user, isLoading, errorMessage];
}
