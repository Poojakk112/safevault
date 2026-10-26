import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/storage/secure_key_store.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase (Auth, Firestore, Storage, Messaging).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 2. Hive local storage. The vault cache is AES-encrypted with a key
  //    kept in the Android Keystore / iOS Keychain (flutter_secure_storage).
  await Hive.initFlutter();
  final key =
      await SecureKeyStore(const FlutterSecureStorage()).getOrCreateHiveKey();
  await Hive.openBox<dynamic>(
    HiveBoxes.vaultCache,
    encryptionCipher: HiveAesCipher(key),
  );
  await Hive.openBox<dynamic>(HiveBoxes.settings);

  // 3. Start the app. ProviderScope enables Riverpod.
  runApp(const ProviderScope(child: SafeVaultApp()));
}
