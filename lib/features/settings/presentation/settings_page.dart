import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import 'settings_controller.dart';

/// Settings screen. Uses Riverpod (ConsumerWidget) instead of BLoC.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(settingsProvider.notifier);
    if (!enable) {
      await controller.setBiometricLock(false);
      return;
    }
    final biometric = ref.read(biometricServiceProvider);
    final available = await biometric.isAvailable();
    if (!context.mounted) return;
    if (!available) {
      _snack(context, 'Set up a fingerprint or screen lock on your phone first.');
      return;
    }
    // Confirm the user can unlock before turning the lock on.
    if (await biometric.authenticate()) {
      await controller.setBiometricLock(true);
    }
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(settingsProvider.notifier);
    final notifications = ref.read(notificationServiceProvider);
    try {
      if (enable) {
        final ok = await notifications.enable();
        if (!ok) {
          if (context.mounted) {
            _snack(context, 'Notification permission was denied.');
          }
          return;
        }
        // Remind the user to review their vault every 6 months.
        await ref.read(apiClientProvider).scheduleReminder(
              title: 'Time to review your SafeVault documents and nominees',
              remindAt: DateTime.now().add(const Duration(days: 180)),
            );
      } else {
        await notifications.disable();
      }
      await controller.setReminders(enable);
    } on Failure catch (f) {
      if (context.mounted) _snack(context, f.message);
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = context.select((AuthBloc b) => b.state.user);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.displayName ?? 'SafeVault user'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Theme'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) =>
                  ref.read(settingsProvider.notifier).setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric lock'),
            subtitle: const Text('Ask for fingerprint / face when opening'),
            value: settings.biometricLock,
            onChanged: (v) => _toggleBiometric(context, ref, v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Review reminders'),
            subtitle: const Text('Push reminder to keep your vault up to date'),
            value: settings.reminders,
            onChanged: (v) => _toggleReminders(context, ref, v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              context.read<AuthBloc>().add(const AuthSignOutRequested());
            },
          ),
        ],
      ),
    );
  }
}
