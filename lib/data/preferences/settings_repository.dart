import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyMaxConcurrent = 'max_concurrent_downloads';
  static const _keyAskBeforeDownload = 'ask_before_download';
  static const _keyDefaultFormat = 'default_format';
  static const _keyDefaultQuality = 'default_quality';
  static const _keyDefaultLocation = 'default_location';
  static const _keyProgressNotifications = 'progress_notifications';
  static const _keyCompletionNotifications = 'completion_notifications';
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyFloatingButton = 'floating_button_enabled';
  static const _keyBatteryFriendly = 'battery_friendly_mode';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  int get maxConcurrentDownloads => _prefs.getInt(_keyMaxConcurrent) ?? 3;
  set maxConcurrentDownloads(int val) => _prefs.setInt(_keyMaxConcurrent, val);

  bool get askBeforeDownload => _prefs.getBool(_keyAskBeforeDownload) ?? true;
  set askBeforeDownload(bool val) => _prefs.setBool(_keyAskBeforeDownload, val);

  String get defaultFormat => _prefs.getString(_keyDefaultFormat) ?? 'video';
  set defaultFormat(String val) => _prefs.setString(_keyDefaultFormat, val);

  String get defaultQuality => _prefs.getString(_keyDefaultQuality) ?? 'Best';
  set defaultQuality(String val) => _prefs.setString(_keyDefaultQuality, val);

  String get defaultLocation => _prefs.getString(_keyDefaultLocation) ?? 'public';
  set defaultLocation(String val) => _prefs.setString(_keyDefaultLocation, val);

  bool get progressNotifications => _prefs.getBool(_keyProgressNotifications) ?? true;
  set progressNotifications(bool val) => _prefs.setBool(_keyProgressNotifications, val);

  bool get completionNotifications => _prefs.getBool(_keyCompletionNotifications) ?? true;
  set completionNotifications(bool val) => _prefs.setBool(_keyCompletionNotifications, val);

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  set themeMode(String val) => _prefs.setString(_keyThemeMode, val);

  bool get floatingButtonEnabled => _prefs.getBool(_keyFloatingButton) ?? false;
  set floatingButtonEnabled(bool val) => _prefs.setBool(_keyFloatingButton, val);

  bool get batteryFriendlyMode => _prefs.getBool(_keyBatteryFriendly) ?? false;
  set batteryFriendlyMode(bool val) => _prefs.setBool(_keyBatteryFriendly, val);
}
