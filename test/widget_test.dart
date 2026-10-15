import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:downloads/data/preferences/settings_repository.dart';
import 'package:downloads/providers/settings_provider.dart';

void main() {
  test('SettingsProvider initialization smoke test', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    final provider = SettingsProvider(repo);

    expect(provider.maxConcurrentDownloads, 3);
    expect(provider.askBeforeDownload, isTrue);
    expect(provider.defaultFormat, 'video');
  });
}
