import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/vault/data/firebase_vault_repository.dart';
import '../features/vault/data/vault_local_cache.dart';
import '../features/vault/domain/vault_repository.dart';
import 'config/app_config.dart';
import 'network/api_client.dart';
import 'services/biometric_service.dart';
import 'services/notification_service.dart';

/// Riverpod providers = the app's dependency injection.
///
/// Every service is created in one place. Widgets and blocs read them with
/// `ref.read(...)`, and tests can replace any of them with `overrideWith`.

final settingsBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>(HiveBoxes.settings),
);

final vaultCacheBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>(HiveBoxes.vaultCache),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => FirebaseVaultRepository(
    cache: VaultLocalCache(ref.watch(vaultCacheBoxProvider)),
  ),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenProvider: auth.getIdToken,
  );
});

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(apiClient: ref.watch(apiClientProvider)),
);
