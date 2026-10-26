import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/providers.dart';

/// User preferences, saved on the phone in a Hive box.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.biometricLock = false,
    this.reminders = false,
  });

  final ThemeMode themeMode;
  final bool biometricLock;
  final bool reminders;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? biometricLock,
    bool? reminders,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        biometricLock: biometricLock ?? this.biometricLock,
        reminders: reminders ?? this.reminders,
      );

  @override
  List<Object?> get props => [themeMode, biometricLock, reminders];
}

/// Riverpod Notifier for settings and theme.
///
/// Any widget that calls `ref.watch(settingsProvider)` rebuilds
/// automatically when a setting changes (for example, the whole app
/// switches to dark mode).
class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'themeMode';
  static const _biometricKey = 'biometricLock';
  static const _remindersKey = 'reminders';

  Box<dynamic> get _box => ref.read(settingsBoxProvider);

  @override
  AppSettings build() {
    final box = ref.watch(settingsBoxProvider);
    final themeIndex = box.get(_themeKey, defaultValue: 0) as int;
    return AppSettings(
      themeMode: ThemeMode.values[themeIndex.clamp(0, 2)],
      biometricLock: box.get(_biometricKey, defaultValue: false) as bool,
      reminders: box.get(_remindersKey, defaultValue: false) as bool,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_themeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setBiometricLock(bool enabled) async {
    await _box.put(_biometricKey, enabled);
    state = state.copyWith(biometricLock: enabled);
  }

  Future<void> setReminders(bool enabled) async {
    await _box.put(_remindersKey, enabled);
    state = state.copyWith(reminders: enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
