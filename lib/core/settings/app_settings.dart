import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MotionPref { system, reduced, full }

/// Device preferences that are not secret (language, theme, motion, biometric unlock).
class AppSettings {
  const AppSettings({this.locale, this.themeMode = ThemeMode.system, this.motion = MotionPref.system, this.biometrics = false});

  /// null → follow the device language (Arabic if the device is Arabic, otherwise English).
  final String? locale;
  final ThemeMode themeMode;
  final MotionPref motion;
  final bool biometrics;

  AppSettings copyWith({String? locale, bool clearLocale = false, ThemeMode? themeMode, MotionPref? motion, bool? biometrics}) => AppSettings(
        locale: clearLocale ? null : (locale ?? this.locale),
        themeMode: themeMode ?? this.themeMode,
        motion: motion ?? this.motion,
        biometrics: biometrics ?? this.biometrics,
      );
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('overridden in main()'));

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() => AppSettings(
        locale: _p.getString('locale'),
        themeMode: ThemeMode.values.byName(_p.getString('theme') ?? 'system'),
        motion: MotionPref.values.byName(_p.getString('motion') ?? 'system'),
        biometrics: _p.getBool('biometrics') ?? false,
      );

  Future<void> setLocale(String? code) async {
    code == null ? await _p.remove('locale') : await _p.setString('locale', code);
    state = state.copyWith(locale: code, clearLocale: code == null);
  }

  Future<void> setTheme(ThemeMode m) async {
    await _p.setString('theme', m.name);
    state = state.copyWith(themeMode: m);
  }

  Future<void> setMotion(MotionPref m) async {
    await _p.setString('motion', m.name);
    state = state.copyWith(motion: m);
  }

  Future<void> setBiometrics(bool on) async {
    await _p.setBool('biometrics', on);
    state = state.copyWith(biometrics: on);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
