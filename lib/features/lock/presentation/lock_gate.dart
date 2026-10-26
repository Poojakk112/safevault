import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../settings/presentation/settings_controller.dart';

/// Shows a lock screen in front of [child] when biometric lock is on.
///
/// The app locks again whenever it goes to the background, so someone who
/// picks up an unlocked phone can't open the vault.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the app went to the background. We only re-lock if it stayed
  /// there for a while, so opening the file picker doesn't lock the app.
  DateTime? _pausedAt;
  static const _relockAfter = Duration(seconds: 30);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) > _relockAfter) {
        setState(() => _unlocked = false);
        _tryUnlock();
      }
    }
  }

  Future<void> _tryUnlock() async {
    if (_unlocked || _authenticating) return;
    if (!ref.read(settingsProvider).biometricLock) return;
    _authenticating = true;
    final ok = await ref.read(biometricServiceProvider).authenticate();
    _authenticating = false;
    if (mounted && ok) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final lockEnabled = ref.watch(settingsProvider).biometricLock;
    if (!lockEnabled || _unlocked) return widget.child;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('SafeVault is locked'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _tryUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
