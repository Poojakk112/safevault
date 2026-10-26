import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:safevault/core/providers.dart';
import 'package:safevault/features/settings/presentation/settings_controller.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('safevault_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('settings_test');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [settingsBoxProvider.overrideWithValue(box)],
      );

  test('defaults: system theme, lock and reminders off', () {
    final container = makeContainer();
    addTearDown(container.dispose);

    expect(container.read(settingsProvider), const AppSettings());
  });

  test('changes are saved and survive an app restart', () async {
    final container = makeContainer();
    final controller = container.read(settingsProvider.notifier);
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setBiometricLock(true);
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    container.dispose();

    // A new container reads the same Hive box, like reopening the app.
    final restarted = makeContainer();
    addTearDown(restarted.dispose);
    final settings = restarted.read(settingsProvider);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.biometricLock, isTrue);
    expect(settings.reminders, isFalse);
  });
}
