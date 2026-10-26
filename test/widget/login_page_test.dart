import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safevault/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:safevault/features/auth/presentation/pages/login_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(const AuthSignOutRequested()));

  setUp(() {
    bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthState.unauthenticated());
  });

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const LoginPage(),
          ),
        ),
      );

  testWidgets('shows validation errors for empty form', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('sends AuthSignInRequested with the typed values',
      (tester) async {
    await pumpLogin(tester);
    await tester.enterText(
        find.byKey(const Key('emailField')), 'pooja@example.com');
    await tester.enterText(
        find.byKey(const Key('passwordField')), 'secret123');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();

    verify(() => bloc.add(const AuthSignInRequested(
          email: 'pooja@example.com',
          password: 'secret123',
        ))).called(1);
  });

  testWidgets('switches to register mode and shows the name field',
      (tester) async {
    await pumpLogin(tester);
    expect(find.byKey(const Key('nameField')), findsNothing);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('shows a SnackBar when the bloc reports an error',
      (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        const AuthState.unauthenticated()
            .copyWith(errorMessage: 'Incorrect email or password.'),
      ]),
      initialState: const AuthState.unauthenticated(),
    );
    await pumpLogin(tester);
    await tester.pump(); // deliver the stream event
    await tester.pump(const Duration(milliseconds: 500)); // SnackBar animates in

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  group('validators', () {
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('not-an-email'), isNotNull);
      expect(validateEmail('pooja@example.com'), isNull);
    });

    test('password', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('123'), isNotNull);
      expect(validatePassword('secret123'), isNull);
    });
  });
}
