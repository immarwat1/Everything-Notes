import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => throw UnimplementedError('SettingsService must be overridden.'),
);

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
      return SettingsController(ref.watch(settingsServiceProvider));
    });

class SettingsService {
  SettingsService(this._box);

  final Box<dynamic> _box;

  static const _boxName = 'everything_notes_settings';

  static Future<SettingsService> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>(_boxName);
    return SettingsService(box);
  }

  AppSettings read() {
    return AppSettings(
      themeMode:
          ThemeMode.values[_box.get(
                'themeMode',
                defaultValue: ThemeMode.system.index,
              )
              as int],
      locale: Locale(_box.get('languageCode', defaultValue: 'en') as String),
      accentColor: Color(
        _box.get('accentColor', defaultValue: 0xFF00C853) as int,
      ),
      editorFontSize: (_box.get('editorFontSize', defaultValue: 17.0) as num)
          .toDouble(),
      pinLockEnabled: _box.get('pinLockEnabled', defaultValue: false) as bool,
      autoBackupEnabled:
          _box.get('autoBackupEnabled', defaultValue: true) as bool,
    );
  }

  Future<void> write(AppSettings settings) async {
    await _box.putAll({
      'themeMode': settings.themeMode.index,
      'languageCode': settings.locale.languageCode,
      'accentColor': settings.accentColor.value,
      'editorFontSize': settings.editorFontSize,
      'pinLockEnabled': settings.pinLockEnabled,
      'autoBackupEnabled': settings.autoBackupEnabled,
    });
  }

  Future<void> putString(String key, String value) => _box.put(key, value);

  String? getString(String key) => _box.get(key) as String?;
}

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.locale,
    required this.accentColor,
    required this.editorFontSize,
    required this.pinLockEnabled,
    required this.autoBackupEnabled,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final Color accentColor;
  final double editorFontSize;
  final bool pinLockEnabled;
  final bool autoBackupEnabled;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    Color? accentColor,
    double? editorFontSize,
    bool? pinLockEnabled,
    bool? autoBackupEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      accentColor: accentColor ?? this.accentColor,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._service) : super(_service.read());

  final SettingsService _service;

  Future<void> update(AppSettings settings) async {
    state = settings;
    await _service.write(settings);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      update(state.copyWith(themeMode: mode));

  Future<void> setLocale(Locale locale) =>
      update(state.copyWith(locale: locale));

  Future<void> setAccentColor(Color color) =>
      update(state.copyWith(accentColor: color));

  Future<void> setEditorFontSize(double fontSize) {
    return update(state.copyWith(editorFontSize: fontSize));
  }

  Future<void> setPinLockEnabled(bool enabled) {
    return update(state.copyWith(pinLockEnabled: enabled));
  }

  Future<void> setAutoBackupEnabled(bool enabled) {
    return update(state.copyWith(autoBackupEnabled: enabled));
  }
}
