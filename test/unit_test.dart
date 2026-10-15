import 'package:flutter_test/flutter_test.dart';
import 'package:downloads/core/utils/url_validator.dart';
import 'package:downloads/core/utils/formatters.dart';
import 'package:downloads/data/models/download_task.dart';

void main() {
  group('UrlValidator Tests', () {
    test('validates standard HTTP and HTTPS URLs', () {
      expect(UrlValidator.isValidUrl('https://example.com/video.mp4'), isTrue);
      expect(UrlValidator.isValidUrl('http://test.org/audio.mp3'), isTrue);
      expect(UrlValidator.isValidUrl('not_a_url'), isFalse);
      expect(UrlValidator.isValidUrl(''), isFalse);
    });

    test('detects YouTube links correctly', () {
      expect(UrlValidator.isYouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTube('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTube('https://example.com/video.mp4'), isFalse);
    });

    test('sanitizes file names', () {
      final sanitized = UrlValidator.sanitizeFileName('video/name:with*illegal?"chars');
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
    });
  });

  group('Formatters Tests', () {
    test('formats byte sizes correctly', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(1024), '1.0 KB');
      expect(Formatters.formatBytes(1048576), '1.0 MB');
      expect(Formatters.formatBytes(1073741824), '1.0 GB');
    });

    test('formats download speed correctly', () {
      expect(Formatters.formatSpeed(0), '0 B/s');
      expect(Formatters.formatSpeed(1048576), '1.0 MB/s');
    });

    test('formats durations correctly', () {
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 15)), '03:15');
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });

  group('DownloadTask Model Tests', () {
    test('calculates progress and percentage accurately', () {
      final task = DownloadTask(
        id: '123',
        notificationId: 1,
        url: 'https://example.com/test.mp4',
        title: 'Test',
        format: 'video',
        quality: '720p',
        filePath: '/tmp/test.mp4',
        downloadedBytes: 50,
        totalBytes: 100,
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.5);
      expect(task.percentage, 50);
    });

    test('handles null totalBytes without error', () {
      final task = DownloadTask(
        id: '124',
        notificationId: 2,
        url: 'https://example.com/stream.mp4',
        title: 'Stream',
        format: 'video',
        quality: 'Best',
        filePath: '/tmp/stream.mp4',
        downloadedBytes: 1024,
        totalBytes: null,
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.0);
      expect(task.percentage, 0);
    });

    test('serializes to and from map', () {
      final original = DownloadTask(
        id: '999',
        notificationId: 42,
        url: 'https://example.com/file.mp4',
        title: 'Serialization Test',
        format: 'video',
        quality: '1080p',
        filePath: '/path/file.mp4',
        downloadedBytes: 500,
        totalBytes: 1000,
        status: DownloadStatus.downloading,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        isPrivate: true,
      );

      final map = original.toMap();
      final reconstructed = DownloadTask.fromMap(map);

      expect(reconstructed.id, original.id);
      expect(reconstructed.url, original.url);
      expect(reconstructed.title, original.title);
      expect(reconstructed.status, original.status);
      expect(reconstructed.isPrivate, isTrue);
    });
  });
}
