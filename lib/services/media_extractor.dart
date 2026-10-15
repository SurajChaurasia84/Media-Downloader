import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/utils/url_validator.dart';
import '../data/models/media_format.dart';
import 'ytdlp_service.dart';

class AppYoutubeHttpClient extends YoutubeHttpClient {
  @override
  Map<String, String> get headers => {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'cookie': 'SOCS=CAESEwgDEgk1ODE5Nzg3NzQaAmVuIAEaBgiA_LyaBg; CONSENT=PENDING+987; YSC=dw1m53a-c-k',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'en-US,en;q=0.9',
    'sec-ch-ua': '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'sec-fetch-user': '?1',
    'upgrade-insecure-requests': '1',
  };
}

class MediaExtractor {
  Future<MediaMetadata> extractMetadata(String url) async {
    final cleanUrl = UrlValidator.extractUrl(url) ?? url.trim();

    if (UrlValidator.isYouTube(cleanUrl)) {
      return await _extractYouTube(cleanUrl);
    }

    // Try yt-dlp first for social platforms (Instagram, TikTok, Twitter, Facebook, etc.)
    try {
      final ytdlpMeta = await YtDlpService.extractInfo(cleanUrl);
      if (ytdlpMeta != null && ytdlpMeta.formats.isNotEmpty) {
        return ytdlpMeta;
      }
    } catch (_) {}

    return await _extractDirect(cleanUrl);
  }

  Future<MediaMetadata> _extractYouTube(String url) async {
    // 1. Try with AppYoutubeHttpClient first (modern Chrome 131 headers)
    try {
      final yt = YoutubeExplode(httpClient: AppYoutubeHttpClient());
      try {
        return await _fetchYouTubeMetadata(yt, url);
      } finally {
        yt.close();
      }
    } catch (e) {
      if (e.toString().contains('RequestLimitExceeded')) {
        // Fallback to default client in case custom client was throttled
        final fallbackYt = YoutubeExplode();
        try {
          return await _fetchYouTubeMetadata(fallbackYt, url);
        } finally {
          fallbackYt.close();
        }
      }
      rethrow;
    }
  }

  Future<MediaMetadata> _fetchYouTubeMetadata(YoutubeExplode yt, String url) async {
    String? videoIdString = UrlValidator.extractYouTubeVideoId(url);
    if (videoIdString == null) {
      try {
        videoIdString = VideoId.parseVideoId(url);
      } catch (_) {}
    }
    if (videoIdString == null) {
      throw Exception('Invalid YouTube URL or Video ID');
    }
    final videoId = VideoId(videoIdString);

    final video = await yt.videos.get(videoId);
    final manifest = await yt.videos.streamsClient.getManifest(videoId);

    final formatOptions = <MediaFormatOption>[];

    // 1. Muxed streams (both video and audio)
    for (final s in manifest.muxed.sortByVideoQuality()) {
      final label = '${s.qualityLabel} (${s.container.name.toUpperCase()})';
      formatOptions.add(
        MediaFormatOption(
          id: s.url.toString(),
          label: label,
          extension: s.container.name,
          sizeBytes: s.size.totalBytes,
          isAudioOnly: false,
          streamInfo: s,
        ),
      );
    }

    // 2. Video only streams (higher qualities like 1080p, 2K, etc.)
    for (final v in manifest.videoOnly.sortByVideoQuality()) {
      final label = '${v.qualityLabel} (${v.container.name.toUpperCase()})';
      // Avoid duplicate labels
      if (!formatOptions.any((f) => f.label == label)) {
        formatOptions.add(
          MediaFormatOption(
            id: v.url.toString(),
            label: label,
            extension: v.container.name,
            sizeBytes: v.size.totalBytes,
            isAudioOnly: false,
            streamInfo: v,
          ),
        );
      }
    }

    // 3. Audio only streams
    for (final a in manifest.audioOnly.sortByBitrate()) {
      final kbps = (a.bitrate.kiloBitsPerSecond).round();
      final label = 'Audio ${kbps}kbps (${a.container.name.toUpperCase()})';
      formatOptions.add(
        MediaFormatOption(
          id: a.url.toString(),
          label: label,
          extension: a.container.name,
          sizeBytes: a.size.totalBytes,
          isAudioOnly: true,
          streamInfo: a,
        ),
      );
    }

    if (formatOptions.isEmpty) {
      throw Exception('No playable video or audio streams found for this video');
    }

    return MediaMetadata(
      url: url,
      title: video.title.isNotEmpty ? video.title : 'YouTube Video',
      author: video.author,
      duration: video.duration,
      thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : video.thumbnails.mediumResUrl,
      formats: formatOptions,
    );
  }

  Future<MediaMetadata> _extractDirect(String url) async {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    // Check for social platforms that require authentication/login
    if (host.contains('instagram.com') || host.contains('instagr.am')) {
      throw Exception(
        'Instagram reels require account login to extract media. Please use YouTube links or direct MP4/video links.',
      );
    }
    if (host.contains('facebook.com') || host.contains('fb.watch')) {
      throw Exception(
        'Facebook video links are protected by Meta. Please use YouTube or direct video download links.',
      );
    }
    if (host.contains('twitter.com') || host.contains('x.com')) {
      throw Exception(
        'X/Twitter links require API authentication. Please use YouTube or direct video download links.',
      );
    }

    // Extract sensible file name without leading dots
    String rawSegment = '';
    for (final seg in uri.pathSegments.reversed) {
      final s = seg.trim();
      if (s.isNotEmpty && s != '.' && s != '..') {
        rawSegment = s;
        break;
      }
    }

    try {
      rawSegment = Uri.decodeComponent(rawSegment);
    } catch (_) {}

    String baseName = rawSegment;
    String ext = '';
    if (rawSegment.contains('.')) {
      final dotIdx = rawSegment.lastIndexOf('.');
      baseName = rawSegment.substring(0, dotIdx);
      ext = rawSegment.substring(dotIdx + 1).toLowerCase();
    }

    // Sanitize base name - strip leading dots
    baseName = baseName.replaceAll(RegExp(r'^\.+'), '').trim();
    if (baseName.isEmpty || baseName == 'mp4' || baseName == 'mp3') {
      baseName = 'video_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    if (ext.isEmpty || ext.length > 5) {
      ext = 'mp4';
    }

    int? contentLength;
    String contentType = '';
    try {
      final response = await http.head(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 8));

      contentType = response.headers['content-type'] ?? '';
      if (response.headers.containsKey('content-length')) {
        contentLength = int.tryParse(response.headers['content-length']!);
      }

      if (contentType.toLowerCase().contains('text/html')) {
        throw Exception(
          'The provided link is an HTML webpage, not a direct video/audio stream.',
        );
      }

      if (contentType.contains('audio')) {
        ext = 'mp3';
      }
    } catch (e) {
      if (e.toString().contains('HTML webpage') ||
          e.toString().contains('Instagram') ||
          e.toString().contains('Facebook') ||
          e.toString().contains('Twitter')) {
        rethrow;
      }
    }

    final isAudio = ['mp3', 'm4a', 'wav', 'flac', 'aac', 'ogg'].contains(ext);

    return MediaMetadata(
      url: url,
      title: baseName,
      formats: [
        MediaFormatOption(
          id: url,
          label: isAudio ? 'Audio ($ext)' : 'Video ($ext)',
          extension: ext,
          sizeBytes: contentLength,
          isAudioOnly: isAudio,
        ),
      ],
    );
  }

  void dispose() {}
}
