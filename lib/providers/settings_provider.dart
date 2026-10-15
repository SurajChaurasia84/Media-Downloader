import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/preferences/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;
  int _totalStorageUsed = 0;

  SettingsProvider(this._repo) {
    calculateStorageUsed();
  }

  int get maxConcurrentDownloads => _repo.maxConcurrentDownloads;
  bool get askBeforeDownload => _repo.askBeforeDownload;
  String get defaultFormat => _repo.defaultFormat;
  String get defaultQuality => _repo.defaultQuality;
  String get defaultLocation => _repo.defaultLocation;
  bool get progressNotifications => _repo.progressNotifications;
  bool get completionNotifications => _repo.completionNotifications;
  String get themeModeString => _repo.themeMode;
  bool get floatingButtonEnabled => _repo.floatingButtonEnabled;
  bool get batteryFriendlyMode => _repo.batteryFriendlyMode;
  int get totalStorageUsed => _totalStorageUsed;

  ThemeMode get themeMode {
    switch (_repo.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setMaxConcurrentDownloads(int count) {
    _repo.maxConcurrentDownloads = count;
    notifyListeners();
  }

  void setAskBeforeDownload(bool val) {
    _repo.askBeforeDownload = val;
    notifyListeners();
  }

  void setDefaultFormat(String format) {
    _repo.defaultFormat = format;
    notifyListeners();
  }

  void setDefaultQuality(String quality) {
    _repo.defaultQuality = quality;
    notifyListeners();
  }

  void setDefaultLocation(String loc) {
    _repo.defaultLocation = loc;
    notifyListeners();
  }

  void setProgressNotifications(bool val) {
    _repo.progressNotifications = val;
    notifyListeners();
  }

  void setCompletionNotifications(bool val) {
    _repo.completionNotifications = val;
    notifyListeners();
  }

  void setThemeMode(String mode) {
    _repo.themeMode = mode;
    notifyListeners();
  }

  void setFloatingButtonEnabled(bool val) {
    _repo.floatingButtonEnabled = val;
    notifyListeners();
  }

  void setBatteryFriendlyMode(bool val) {
    _repo.batteryFriendlyMode = val;
    notifyListeners();
  }

  Future<void> calculateStorageUsed() async {
    int total = 0;
    try {
      Directory? docDir = await getExternalStorageDirectory();
      docDir ??= await getApplicationDocumentsDirectory();
      final publicDir = Directory(p.join(docDir.path, 'Downloads'));
      if (await publicDir.exists()) {
        await for (final f in publicDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            total += await f.length();
          }
        }
      }

      final supportDir = await getApplicationSupportDirectory();
      final privDir = Directory(p.join(supportDir.path, 'PrivateVault'));
      if (await privDir.exists()) {
        await for (final f in privDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            total += await f.length();
          }
        }
      }
    } catch (_) {}

    _totalStorageUsed = total;
    notifyListeners();
  }
}
