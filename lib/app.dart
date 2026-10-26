import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/lock/presentation/lock_gate.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/vault/presentation/bloc/documents_bloc.dart';
import 'features/vault/presentation/bloc/nominees_cubit.dart';
import 'features/vault/presentation/pages/home_page.dart';

/// Used to show SnackBars from anywhere (e.g. push notifications).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Root widget.
///
/// Riverpod (ConsumerWidget) watches settings, so changing the theme
/// rebuilds MaterialApp. The AuthBloc is created once and provided to
/// the whole app.
class SafeVaultApp extends ConsumerWidget {
  const SafeVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return BlocProvider(
      create: (_) => AuthBloc(ref.read(authRepositoryProvider))
        ..add(const AuthSubscriptionRequested()),
      child: MaterialApp(
        title: 'SafeVault',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const AuthGate(),
      ),
    );
  }
}

/// Chooses the first screen based on the sign-in state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.user?.uid != curr.user?.uid,
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.authenticated:
            final uid = state.user!.uid;
            return LockGate(
              // A new key per user makes sure blocs are recreated on switch.
              child: VaultShell(key: ValueKey(uid), uid: uid),
            );
        }
      },
    );
  }
}

/// Provides the vault blocs for the signed-in user and starts
/// push notifications if the user turned reminders on.
class VaultShell extends ConsumerStatefulWidget {
  const VaultShell({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<VaultShell> createState() => _VaultShellState();
}

class _VaultShellState extends ConsumerState<VaultShell> {
  StreamSubscription<dynamic>? _messagesSub;

  @override
  void initState() {
    super.initState();
    final notifications = ref.read(notificationServiceProvider);
    if (ref.read(settingsProvider).reminders) {
      notifications.enable().catchError((Object _) => false);
    }
    _messagesSub = notifications.foregroundMessages.listen((message) {
      final title = message.notification?.title;
      if (title != null) {
        scaffoldMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text(title)));
      }
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(vaultRepositoryProvider);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DocumentsBloc(repository: repository, uid: widget.uid)
            ..add(const DocumentsStarted()),
        ),
        BlocProvider(
          create: (_) =>
              NomineesCubit(repository: repository, uid: widget.uid)..start(),
        ),
      ],
      child: const HomePage(),
    );
  }
}
