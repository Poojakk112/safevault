import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safevault/core/errors/failures.dart';
import 'package:safevault/features/auth/domain/app_user.dart';
import 'package:safevault/features/auth/domain/auth_repository.dart';
import 'package:safevault/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  const user = AppUser(uid: 'u1', email: 'pooja@example.com');

  setUp(() => repo = MockAuthRepository());

  test('initial state is unknown', () {
    expect(AuthBloc(repo).state, const AuthState.unknown());
  });

  blocTest<AuthBloc, AuthState>(
    'emits authenticated / unauthenticated from the auth stream',
    setUp: () => when(() => repo.authStateChanges())
        .thenAnswer((_) => Stream.fromIterable([user, null])),
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
    expect: () => const [
      AuthState.authenticated(user),
      AuthState.unauthenticated(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'shows loading then error message when sign in fails',
    setUp: () => when(() => repo.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const AuthFailure('Incorrect email or password.')),
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(
      const AuthSignInRequested(email: 'a@b.com', password: 'wrong1'),
    ),
    expect: () => [
      const AuthState.unknown().copyWith(isLoading: true),
      const AuthState.unknown().copyWith(
        isLoading: false,
        errorMessage: 'Incorrect email or password.',
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'calls the repository on register and stops loading on success',
    setUp: () => when(() => repo.registerWithEmail(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {}),
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(const AuthRegisterRequested(
      name: 'Pooja',
      email: 'pooja@example.com',
      password: 'secret123',
    )),
    expect: () => [
      const AuthState.unknown().copyWith(isLoading: true),
      const AuthState.unknown().copyWith(isLoading: false),
    ],
    verify: (_) => verify(() => repo.registerWithEmail(
          name: 'Pooja',
          email: 'pooja@example.com',
          password: 'secret123',
        )).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'sign out calls the repository',
    setUp: () => when(() => repo.signOut()).thenAnswer((_) async {}),
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(const AuthSignOutRequested()),
    verify: (_) => verify(() => repo.signOut()).called(1),
  );
}
