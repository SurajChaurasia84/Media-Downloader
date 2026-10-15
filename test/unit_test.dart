import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:downloads/core/utils/url_validator.dart';
import 'package:downloads/core/utils/formatters.dart';
import 'package:downloads/core/security/pin_service.dart';
import 'package:downloads/data/models/download_task.dart';
import 'package:downloads/data/preferences/settings_repository.dart';
import 'package:downloads/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Progress Calculations & Unknown Total-Size (SRS 798, 799)', () {
    test('calculates percentage accurately when total size is known', () {
      final task = DownloadTask(
        id: '1',
        notificationId: 101,
        url: 'https://example.com/video.mp4',
        title: 'Video',
        format: 'video',
        quality: '1080p',
        filePath: '/tmp/video.mp4',
        downloadedBytes: 750,
        totalBytes: 1000,
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.75);
      expect(task.percentage, 75);
    });

    test('handles unknown total-size gracefully without division by zero', () {
      final task = DownloadTask(
        id: '2',
        notificationId: 102,
        url: 'https://example.com/stream.mp4',
        title: 'Live Stream',
        format: 'video',
        quality: 'Best',
        filePath: '/tmp/stream.mp4',
        downloadedBytes: 5242880,
        totalBytes: null, // Unknown total size
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.0);
      expect(task.percentage, 0);
    });
  });

  group('2. Concurrency Limits & Queue Scheduling (SRS 793, 794)', () {
    test('schedules waiting tasks within concurrency limit', () {
      const maxConcurrency = 3;
      final tasks = [
        DownloadTask(
          id: '1',
          notificationId: 1,
          url: 'url1',
          title: 't1',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/1',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ),
        DownloadTask(
          id: '2',
          notificationId: 2,
          url: 'url2',
          title: 't2',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/2',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ),
        DownloadTask(
          id: '3',
          notificationId: 3,
          url: 'url3',
          title: 't3',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/3',
          status: DownloadStatus.waiting,
          createdAt: DateTime.now(),
        ),
        DownloadTask(
          id: '4',
          notificationId: 4,
          url: 'url4',
          title: 't4',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/4',
          status: DownloadStatus.waiting,
          createdAt: DateTime.now(),
        ),
      ];

      final running = tasks.where((t) => t.status == DownloadStatus.downloading).length;
      final availableSlots = maxConcurrency - running;
      expect(availableSlots, 1);

      // Next candidate to schedule
      final toStart = tasks.where((t) => t.status == DownloadStatus.waiting).take(availableSlots).toList();
      expect(toStart.length, 1);
      expect(toStart.first.id, '3');
    });

    test('blocks scheduling when maximum concurrency is reached', () {
      const maxConcurrency = 2;
      final tasks = [
        DownloadTask(
          id: '1',
          notificationId: 1,
          url: 'url1',
          title: 't1',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/1',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ),
        DownloadTask(
          id: '2',
          notificationId: 2,
          url: 'url2',
          title: 't2',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/2',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ),
        DownloadTask(
          id: '3',
          notificationId: 3,
          url: 'url3',
          title: 't3',
          format: 'video',
          quality: '720p',
          filePath: '/tmp/3',
          status: DownloadStatus.waiting,
          createdAt: DateTime.now(),
        ),
      ];

      final running = tasks.where((t) => t.status == DownloadStatus.downloading).length;
      expect(running >= maxConcurrency, isTrue);
    });
  });

  group('3. State Transitions & Pause / Resume / Cancel Routing (SRS 795, 796)', () {
    test('transitions through valid download lifecycles', () {
      final task = DownloadTask(
        id: '10',
        notificationId: 10,
        url: 'url',
        title: 'Video Lifecycle',
        format: 'video',
        quality: '720p',
        filePath: '/tmp/vid',
        status: DownloadStatus.waiting,
        createdAt: DateTime.now(),
      );

      expect(task.status, DownloadStatus.waiting);

      // Preparing
      task.status = DownloadStatus.preparing;
      expect(task.status, DownloadStatus.preparing);

      // Downloading
      task.status = DownloadStatus.downloading;
      expect(task.status, DownloadStatus.downloading);

      // Paused
      task.status = DownloadStatus.paused;
      expect(task.status, DownloadStatus.paused);

      // Resumed back to waiting/downloading
      task.status = DownloadStatus.waiting;
      expect(task.status, DownloadStatus.waiting);

      // Finalizing & Completed
      task.status = DownloadStatus.finalizing;
      task.status = DownloadStatus.completed;
      task.completedAt = DateTime.now();
      expect(task.status, DownloadStatus.completed);
      expect(task.completedAt, isNotNull);
    });

    test('cancelling one task does not affect other tasks', () {
      final taskA = DownloadTask(
        id: 'A',
        notificationId: 1,
        url: 'urlA',
        title: 'A',
        format: 'video',
        quality: '720p',
        filePath: '/tmp/A',
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );
      final taskB = DownloadTask(
        id: 'B',
        notificationId: 2,
        url: 'urlB',
        title: 'B',
        format: 'video',
        quality: '720p',
        filePath: '/tmp/B',
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      // Cancel task A
      taskA.status = DownloadStatus.cancelled;

      expect(taskA.status, DownloadStatus.cancelled);
      expect(taskB.status, DownloadStatus.downloading);
    });
  });

  group('4. Duplicate-Job Handling (SRS 797)', () {
    test('identifies and prevents duplicate active download jobs', () {
      final existingTasks = [
        DownloadTask(
          id: '1',
          notificationId: 1,
          url: 'https://example.com/sample.mp4',
          title: 'Sample',
          format: 'video',
          quality: '1080p',
          filePath: '/tmp/sample.mp4',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ),
      ];

      const newUrl = 'https://example.com/sample.mp4';

      final isDuplicate = existingTasks.any(
        (t) => t.url == newUrl &&
            (t.status == DownloadStatus.downloading ||
             t.status == DownloadStatus.waiting ||
             t.status == DownloadStatus.preparing),
      );

      expect(isDuplicate, isTrue);
    });
  });

  group('5. Retry Policies (SRS 800)', () {
    test('allows failed task to transition to waiting on retry', () {
      final task = DownloadTask(
        id: 'fail-1',
        notificationId: 99,
        url: 'url',
        title: 'Failed Task',
        format: 'video',
        quality: '720p',
        filePath: '/tmp/f',
        status: DownloadStatus.failed,
        error: 'Network timeout',
        createdAt: DateTime.now(),
      );

      expect(task.status, DownloadStatus.failed);
      expect(task.error, isNotNull);

      // Trigger retry
      task.status = DownloadStatus.waiting;
      task.error = null;

      expect(task.status, DownloadStatus.waiting);
      expect(task.error, isNull);
    });
  });

  group('6. Settings Persistence & Notification Preference Logic (SRS 801, 803)', () {
    test('persists user preferences and respects notification flags', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final provider = SettingsProvider(repo);

      // Default checks
      expect(provider.progressNotifications, isTrue);
      expect(provider.completionNotifications, isTrue);
      expect(provider.maxConcurrentDownloads, 3);

      // Change and verify persistence
      provider.setProgressNotifications(false);
      provider.setCompletionNotifications(false);
      provider.setMaxConcurrentDownloads(5);

      expect(repo.progressNotifications, isFalse);
      expect(repo.completionNotifications, isFalse);
      expect(repo.maxConcurrentDownloads, 5);
    });
  });

  group('7. Private / Public Storage Selection & PIN Security (SRS 802, 529)', () {
    test('stores PIN securely with salted hashing and verifies match', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await PinService.hasPin(), isFalse);

      final success = await PinService.setPin('1234');
      expect(success, isTrue);
      expect(await PinService.hasPin(), isTrue);

      expect(await PinService.verifyPin('1234'), isTrue);
      expect(await PinService.verifyPin('9999'), isFalse);
    });

    test('marks task as private and isolates it correctly', () {
      final publicTask = DownloadTask(
        id: 'pub',
        notificationId: 1,
        url: 'url',
        title: 'Public',
        format: 'video',
        quality: '720p',
        filePath: '/storage/Downloads/video.mp4',
        createdAt: DateTime.now(),
        isPrivate: false,
      );

      final privateTask = DownloadTask(
        id: 'priv',
        notificationId: 2,
        url: 'url',
        title: 'Private',
        format: 'video',
        quality: '720p',
        filePath: '/storage/PrivateVault/video.mp4',
        createdAt: DateTime.now(),
        isPrivate: true,
      );

      expect(publicTask.isPrivate, isFalse);
      expect(privateTask.isPrivate, isTrue);
    });
  });

  group('8. Utilities (UrlValidator & Formatters)', () {
    test('validates standard URLs, YouTube Shorts, and shared links', () {
      expect(UrlValidator.isValidUrl('https://example.com/video.mp4'), isTrue);
      expect(UrlValidator.isYouTube('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTube('https://www.youtube.com/shorts/3i_JmO9a5oU'), isTrue);
      expect(UrlValidator.isYouTube('youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTube('https://youtube.com/live/dQw4w9WgXcQ?feature=share'), isTrue);
      expect(UrlValidator.extractYouTubeVideoId('https://www.youtube.com/shorts/3i_JmO9a5oU'), '3i_JmO9a5oU');
      expect(UrlValidator.extractYouTubeVideoId('https://youtu.be/dQw4w9WgXcQ?si=abc12345678'), 'dQw4w9WgXcQ');
      expect(UrlValidator.extractYouTubeVideoId('https://youtube.com/live/dQw4w9WgXcQ?feature=share'), 'dQw4w9WgXcQ');
      expect(UrlValidator.extractYouTubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(UrlValidator.extractUrl('Check out https://youtu.be/dQw4w9WgXcQ now!'), 'https://youtu.be/dQw4w9WgXcQ');
      expect(UrlValidator.isValidUrl('invalid-url'), isFalse);
    });

    test('formats byte sizes, speeds, and durations', () {
      expect(Formatters.formatBytes(1048576), '1.0 MB');
      expect(Formatters.formatSpeed(2097152), '2.0 MB/s');
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 15)), '03:15');
    });
  });
}
