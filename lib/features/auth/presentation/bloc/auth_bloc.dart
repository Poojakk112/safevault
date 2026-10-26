import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// BLoC for the sign-in flow.
///
/// UI  --(AuthEvent)-->  AuthBloc  --(AuthState)-->  UI rebuilds
///
/// The bloc never touches Firebase directly; it only uses [AuthRepository].
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _repository;

  /// Keeps the state in sync with Firebase. emit.forEach cancels the
  /// subscription automatically when the bloc is closed.
  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) =>
      emit.forEach<AppUser?>(
        _repository.authStateChanges(),
        onData: (user) => user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
        onError: (_, __) => const AuthState.unauthenticated(),
      );

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) =>
      _run(
        emit,
        () => _repository.signInWithEmail(
          email: event.email,
          password: event.password,
        ),
      );

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) =>
      _run(
        emit,
        () => _repository.registerWithEmail(
          name: event.name,
          email: event.email,
          password: event.password,
        ),
      );

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) =>
      _run(emit, _repository.signInWithGoogle);

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) =>
      _repository.signOut();

  /// Shows a loading spinner while [action] runs, and an error if it fails.
  /// On success the auth stream emits the new user, which updates the state.
  Future<void> _run(
    Emitter<AuthState> emit,
    Future<void> Function() action,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await action();
      emit(state.copyWith(isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      ));
    }
  }
}
