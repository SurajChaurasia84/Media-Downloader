class UrlValidator {
  static bool isValidUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final url = extractUrl(trimmed);
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static String? extractUrl(String input) {
    final trimmed = input.trim();
    final regExp = RegExp(r'https?:\/\/[^\s]+');
    final match = regExp.firstMatch(trimmed);
    if (match != null) {
      return match.group(0);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be') ||
        trimmed.contains('www.') ||
        RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(\/.*)?$').hasMatch(trimmed)) {
      return 'https://$trimmed';
    }
    return null;
  }

  static bool isYouTube(String input) {
    final trimmed = input.trim().toLowerCase();
    return trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be') ||
        trimmed.contains('yt.be') ||
        extractYouTubeVideoId(input) != null;
  }

  static String? extractYouTubeVideoId(String input) {
    final clean = input.trim();

    // 1. YouTube Shorts: youtube.com/shorts/{id}
    final shortsMatch = RegExp(r'shorts\/([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (shortsMatch != null) return shortsMatch.group(1);

    // 2. Short URL: youtu.be/{id}
    final youtuBeMatch = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (youtuBeMatch != null) return youtuBeMatch.group(1);

    // 3. Query param: v={id}
    final vMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (vMatch != null) return vMatch.group(1);

    // 4. Live: /live/{id}
    final liveMatch = RegExp(r'live\/([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (liveMatch != null) return liveMatch.group(1);

    // 5. Embed: /embed/{id}
    final embedMatch = RegExp(r'embed\/([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (embedMatch != null) return embedMatch.group(1);

    // 6. /v/{id}
    final vSlashMatch = RegExp(r'\/v\/([a-zA-Z0-9_-]{11})').firstMatch(clean);
    if (vSlashMatch != null) return vSlashMatch.group(1);

    // 7. Raw 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) return clean;

    return null;
  }

  static String sanitizeFileName(String name) {
    var sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '').trim();
    return sanitized;
  }
}
