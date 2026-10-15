import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/utils/url_validator.dart';
import '../data/models/media_format.dart';

class MediaExtractor {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<MediaMetadata> extractMetadata(String url) async {
    final cleanUrl = url.trim();

    if (UrlValidator.isYouTube(cleanUrl)) {
      return await _extractYouTube(cleanUrl);
    } else {
      return await _extractDirect(cleanUrl);
    }
  }

  Future<MediaMetadata> _extractYouTube(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final formatOptions = <MediaFormatOption>[];

      // Muxed streams (both video and audio)
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

      // Audio only streams
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

      // If no muxed found, also check video-only
      if (formatOptions.isEmpty) {
        for (final v in manifest.videoOnly.sortByVideoQuality()) {
          formatOptions.add(
            MediaFormatOption(
              id: v.url.toString(),
              label: '${v.qualityLabel} (Video Only)',
              extension: v.container.name,
              sizeBytes: v.size.totalBytes,
              isAudioOnly: false,
              streamInfo: v,
            ),
          );
        }
      }

      return MediaMetadata(
        url: url,
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.mediumResUrl,
        formats: formatOptions,
      );
    } catch (e) {
      throw Exception('Extraction failed: $e');
    }
  }

  Future<MediaMetadata> _extractDirect(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.head(uri).timeout(const Duration(seconds: 8));

      int? contentLength;
      if (response.headers.containsKey('content-length')) {
        contentLength = int.tryParse(response.headers['content-length']!);
      }

      String fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'media_file';
      if (!fileName.contains('.')) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('audio')) {
          fileName += '.mp3';
        } else {
          fileName += '.mp4';
        }
      }

      final ext = fileName.split('.').last.toLowerCase();
      final isAudio = ['mp3', 'm4a', 'wav', 'flac', 'aac', 'ogg'].contains(ext);

      return MediaMetadata(
        url: url,
        title: fileName,
        formats: [
          MediaFormatOption(
            id: url,
            label: isAudio ? 'Audio ($ext)' : 'Direct Video ($ext)',
            extension: ext,
            sizeBytes: contentLength,
            isAudioOnly: isAudio,
          ),
        ],
      );
    } catch (_) {
      // Fallback if HEAD is blocked or fails
      final uri = Uri.parse(url);
      String fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'download_file.mp4';
      final ext = fileName.contains('.') ? fileName.split('.').last : 'mp4';
      final isAudio = ['mp3', 'm4a', 'wav', 'flac', 'aac'].contains(ext);

      return MediaMetadata(
        url: url,
        title: fileName,
        formats: [
          MediaFormatOption(
            id: url,
            label: isAudio ? 'Audio ($ext)' : 'Video ($ext)',
            extension: ext,
            isAudioOnly: isAudio,
          ),
        ],
      );
    }
  }

  void dispose() {
    _yt.close();
  }
}
