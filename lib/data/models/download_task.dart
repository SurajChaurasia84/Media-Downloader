enum DownloadStatus {
  waiting,
  preparing,
  downloading,
  paused,
  finalizing,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final int notificationId;
  final String url;
  String title;
  String? thumbnailUrl;
  final String format; // 'video' | 'audio'
  final String quality;
  String filePath;
  int downloadedBytes;
  int? totalBytes;
  double speed; // bytes per second
  DownloadStatus status;
  final DateTime createdAt;
  final int? durationSeconds;
  DateTime? completedAt;
  bool isPrivate;
  String? error;

  DownloadTask({
    required this.id,
    required this.notificationId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    required this.format,
    required this.quality,
    required this.filePath,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.speed = 0,
    this.status = DownloadStatus.waiting,
    this.durationSeconds,
    required this.createdAt,
    this.completedAt,
    this.isPrivate = false,
    this.error,
  });

  double get progress {
    if (totalBytes == null || totalBytes! <= 0) return 0;
    return (downloadedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  int get percentage {
    return (progress * 100).toInt();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notification_id': notificationId,
      'url': url,
      'title': title,
      'thumbnail_url': thumbnailUrl,
      'format': format,
      'quality': quality,
      'file_path': filePath,
      'downloaded_bytes': downloadedBytes,
      'total_bytes': totalBytes,
      'duration_seconds': durationSeconds,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'is_private': isPrivate ? 1 : 0,
      'error': error,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      notificationId: map['notification_id'] as int? ?? map['id'].hashCode.abs() % 100000,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      format: map['format'] as String? ?? 'video',
      quality: map['quality'] as String? ?? 'Best',
      filePath: map['file_path'] as String,
      downloadedBytes: (map['downloaded_bytes'] as int?) ?? 0,
      totalBytes: map['total_bytes'] as int?,
      durationSeconds: map['duration_seconds'] as int?,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DownloadStatus.failed,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      isPrivate: (map['is_private'] as int? ?? 0) == 1,
      error: map['error'] as String?,
    );
  }
}
