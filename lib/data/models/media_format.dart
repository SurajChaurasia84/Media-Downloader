class MediaFormatOption {
  final String id;
  final String label; // e.g. "1080p", "720p", "360p", "Audio M4A"
  final String extension; // "mp4", "m4a", "mp3"
  final int? sizeBytes;
  final bool isAudioOnly;
  final dynamic streamInfo; // Extractor stream reference if applicable

  MediaFormatOption({
    required this.id,
    required this.label,
    required this.extension,
    this.sizeBytes,
    required this.isAudioOnly,
    this.streamInfo,
  });
}

class MediaMetadata {
  final String url;
  final String title;
  final String? author;
  final Duration? duration;
  final String? thumbnailUrl;
  final List<MediaFormatOption> formats;

  MediaMetadata({
    required this.url,
    required this.title,
    this.author,
    this.duration,
    this.thumbnailUrl,
    required this.formats,
  });
}
