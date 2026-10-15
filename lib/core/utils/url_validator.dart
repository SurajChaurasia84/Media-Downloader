class UrlValidator {
  static bool isValidUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static bool isYouTube(String input) {
    final trimmed = input.trim().toLowerCase();
    return trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be') ||
        trimmed.contains('m.youtube.com');
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
