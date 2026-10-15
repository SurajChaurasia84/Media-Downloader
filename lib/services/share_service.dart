import 'package:flutter/services.dart';
import '../core/utils/url_validator.dart';

class ShareService {
  static const _channel = MethodChannel('com.downloads.app/share');
  static void Function(String url)? _onUrlReceived;

  static void initialize(void Function(String url) onReceived) {
    _onUrlReceived = onReceived;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final text = call.arguments as String?;
        if (text != null) {
          final url = UrlValidator.extractUrl(text) ?? text.trim();
          if (url.isNotEmpty) {
            _onUrlReceived?.call(url);
          }
        }
      }
    });

    // Check if app was launched via share intent
    checkInitialShare();
  }

  static Future<void> checkInitialShare() async {
    try {
      final initialText = await _channel.invokeMethod<String>('getInitialSharedText');
      if (initialText != null && initialText.isNotEmpty) {
        final url = UrlValidator.extractUrl(initialText) ?? initialText.trim();
        if (url.isNotEmpty) {
          _onUrlReceived?.call(url);
        }
      }
    } catch (_) {}
  }
}
