import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../core/notifications/notification_service.dart';
import '../core/utils/url_validator.dart';
import '../data/database/app_database.dart';
import '../data/models/download_task.dart';
import '../data/models/media_format.dart';
import '../data/preferences/settings_repository.dart';

class DownloadEngine {
  final AppDatabase _db = AppDatabase();
  final NotificationService _notifications = NotificationService();
  final SettingsRepository _settings;

  final Map<String, http.Client> _activeClients = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, IOSink> _activeSinks = {};
  final Map<String, int> _lastReportedTime = {};
  final Map<String, int> _lastReportedBytes = {};

  final void Function(DownloadTask task) onTaskUpdated;

  DownloadEngine({
    required this._settings,
    required this.onTaskUpdated,
  });

  Future<String> getPublicDownloadDir() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();
    final downloadPath = p.join(dir.path, 'Downloads');
    final d = Directory(downloadPath);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return downloadPath;
  }

  Future<String> getPrivateDownloadDir() async {
    final dir = await getApplicationSupportDirectory();
    final privatePath = p.join(dir.path, 'PrivateVault');
    final d = Directory(privatePath);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return privatePath;
  }

  Future<DownloadTask> createTask({
    required String url,
    required String title,
    required MediaFormatOption format,
    String? thumbnailUrl,
    bool? isPrivate,
  }) async {
    final savePrivate = isPrivate ?? (_settings.defaultLocation == 'private');
    final targetDir = savePrivate
        ? await getPrivateDownloadDir()
        : await getPublicDownloadDir();

    final safeTitle = UrlValidator.sanitizeFileName(title);
    final ext = format.extension.isNotEmpty ? format.extension : 'mp4';
    final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final targetPath = p.join(targetDir, fileName);

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final notificationId = taskId.hashCode.abs() % 100000;

    final task = DownloadTask(
      id: taskId,
      notificationId: notificationId,
      url: url,
      title: title,
      thumbnailUrl: thumbnailUrl,
      format: format.isAudioOnly ? 'audio' : 'video',
      quality: format.label,
      filePath: targetPath,
      totalBytes: format.sizeBytes,
      status: DownloadStatus.waiting,
      createdAt: DateTime.now(),
      isPrivate: savePrivate,
    );

    await _db.insertTask(task);
    return task;
  }

  void checkQueue(List<DownloadTask> tasks) {
    final maxConcurrent = _settings.maxConcurrentDownloads;
    final runningTasks = tasks.where((t) => t.status == DownloadStatus.downloading).toList();
    if (runningTasks.length >= maxConcurrent) return;

    final slots = maxConcurrent - runningTasks.length;
    final waiting = tasks.where((t) => t.status == DownloadStatus.waiting).take(slots);

    for (final task in waiting) {
      startDownload(task, tasks);
    }
  }

  Future<void> startDownload(DownloadTask task, List<DownloadTask> allTasks) async {
    if (task.status == DownloadStatus.downloading) return;

    task.status = DownloadStatus.preparing;
    task.error = null;
    onTaskUpdated(task);

    final partFilePath = '${task.filePath}.part';
    final partFile = File(partFilePath);

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }
    task.downloadedBytes = existingBytes;

    if (UrlValidator.isYouTube(task.url)) {
      await _downloadYouTube(task, partFile, existingBytes, allTasks);
    } else {
      await _downloadHttp(task, partFile, existingBytes, allTasks);
    }
  }

  Future<void> _downloadYouTube(
    DownloadTask task,
    File partFile,
    int existingBytes,
    List<DownloadTask> allTasks,
  ) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final video = await yt.videos.get(task.url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      StreamInfo? streamInfo;
      if (task.format == 'audio') {
        streamInfo = manifest.audioOnly.withHighestBitrate();
      } else {
        // Try muxed first
        final muxed = manifest.muxed.sortByVideoQuality();
        if (muxed.isNotEmpty) {
          streamInfo = muxed.first;
        } else {
          final videoOnly = manifest.videoOnly.sortByVideoQuality();
          if (videoOnly.isNotEmpty) streamInfo = videoOnly.first;
        }
      }

      if (streamInfo == null) {
        throw Exception('Stream not found');
      }

      task.totalBytes = streamInfo.size.totalBytes;
      task.status = DownloadStatus.downloading;
      onTaskUpdated(task);

      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = partFile.openWrite(
        mode: existingBytes > 0 && existingBytes == task.downloadedBytes
            ? FileMode.append
            : FileMode.write,
      );
      _activeSinks[task.id] = sink;

      int bytesCounter = 0;
      var lastTick = DateTime.now();
      _lastReportedTime[task.id] = DateTime.now().millisecondsSinceEpoch;
      _lastReportedBytes[task.id] = task.downloadedBytes;

      final sub = stream.listen(
        (chunk) {
          sink.add(chunk);
          task.downloadedBytes += chunk.length;
          bytesCounter += chunk.length;

          final now = DateTime.now();
          final diff = now.difference(lastTick).inMilliseconds;
          if (diff >= 750) {
            task.speed = (bytesCounter / (diff / 1000.0));
            bytesCounter = 0;
            lastTick = now;
            _notifyProgress(task);
            onTaskUpdated(task);
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          _activeSinks.remove(task.id);
          _activeSubscriptions.remove(task.id);
          yt?.close();

          await _finalizeDownload(task, partFile, allTasks);
        },
        onError: (err) async {
          await sink.close();
          _activeSinks.remove(task.id);
          _activeSubscriptions.remove(task.id);
          yt?.close();

          task.status = DownloadStatus.failed;
          task.error = err.toString();
          onTaskUpdated(task);
          await _db.updateTask(task);
          checkQueue(allTasks);
        },
        cancelOnError: true,
      );

      _activeSubscriptions[task.id] = sub;
    } catch (e) {
      yt?.close();
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      onTaskUpdated(task);
      await _db.updateTask(task);
      checkQueue(allTasks);
    }
  }

  Future<void> _downloadHttp(
    DownloadTask task,
    File partFile,
    int existingBytes,
    List<DownloadTask> allTasks,
  ) async {
    final client = http.Client();
    _activeClients[task.id] = client;

    try {
      final request = http.Request('GET', Uri.parse(task.url));
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await client.send(request);

      if (response.statusCode == 200) {
        // Full file returned, reset existing
        existingBytes = 0;
        task.downloadedBytes = 0;
        task.totalBytes = response.contentLength;
      } else if (response.statusCode == 206) {
        // Resuming supported
        final total = response.contentLength;
        if (total != null) {
          task.totalBytes = existingBytes + total;
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }

      task.status = DownloadStatus.downloading;
      onTaskUpdated(task);

      final sink = partFile.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );
      _activeSinks[task.id] = sink;

      int bytesCounter = 0;
      var lastTick = DateTime.now();

      final sub = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          task.downloadedBytes += chunk.length;
          bytesCounter += chunk.length;

          final now = DateTime.now();
          final diff = now.difference(lastTick).inMilliseconds;
          if (diff >= 750) {
            task.speed = (bytesCounter / (diff / 1000.0));
            bytesCounter = 0;
            lastTick = now;
            _notifyProgress(task);
            onTaskUpdated(task);
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          _activeClients.remove(task.id);
          _activeSinks.remove(task.id);
          _activeSubscriptions.remove(task.id);

          await _finalizeDownload(task, partFile, allTasks);
        },
        onError: (err) async {
          await sink.close();
          _activeClients.remove(task.id);
          _activeSinks.remove(task.id);
          _activeSubscriptions.remove(task.id);

          task.status = DownloadStatus.failed;
          task.error = err.toString();
          onTaskUpdated(task);
          await _db.updateTask(task);
          checkQueue(allTasks);
        },
        cancelOnError: true,
      );

      _activeSubscriptions[task.id] = sub;
    } catch (e) {
      _activeClients.remove(task.id);
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      onTaskUpdated(task);
      await _db.updateTask(task);
      checkQueue(allTasks);
    }
  }

  void _notifyProgress(DownloadTask task) {
    if (!_settings.progressNotifications) return;
    _notifications.showProgressNotification(
      id: task.notificationId,
      title: task.title,
      progress: task.percentage,
      body: '${task.percentage}% • ${(task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      indeterminate: task.totalBytes == null || task.totalBytes! <= 0,
    );
  }

  Future<void> _finalizeDownload(
    DownloadTask task,
    File partFile,
    List<DownloadTask> allTasks,
  ) async {
    task.status = DownloadStatus.finalizing;
    task.speed = 0;
    onTaskUpdated(task);

    if (await partFile.exists()) {
      final finalFile = File(task.filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await partFile.rename(task.filePath);
    }

    task.status = DownloadStatus.completed;
    task.completedAt = DateTime.now();
    await _db.updateTask(task);
    onTaskUpdated(task);

    await _notifications.cancel(task.notificationId);

    if (_settings.completionNotifications) {
      await _notifications.showCompletionNotification(
        id: task.notificationId + 50000,
        title: 'Download complete',
        body: task.title,
        filePath: task.filePath,
      );
    }

    checkQueue(allTasks);
  }

  Future<void> pauseDownload(DownloadTask task, List<DownloadTask> allTasks) async {
    if (task.status != DownloadStatus.downloading &&
        task.status != DownloadStatus.preparing) {
      return;
    }

    await _cancelActiveStreams(task.id);
    task.status = DownloadStatus.paused;
    task.speed = 0;
    await _db.updateTask(task);
    onTaskUpdated(task);

    await _notifications.cancel(task.notificationId);
    checkQueue(allTasks);
  }

  Future<void> resumeDownload(DownloadTask task, List<DownloadTask> allTasks) async {
    if (task.status != DownloadStatus.paused &&
        task.status != DownloadStatus.failed) {
      return;
    }

    task.status = DownloadStatus.waiting;
    task.error = null;
    await _db.updateTask(task);
    onTaskUpdated(task);

    checkQueue(allTasks);
  }

  Future<void> cancelDownload(DownloadTask task, List<DownloadTask> allTasks) async {
    await _cancelActiveStreams(task.id);

    final partFile = File('${task.filePath}.part');
    if (await partFile.exists()) {
      try {
        await partFile.delete();
      } catch (_) {}
    }

    task.status = DownloadStatus.cancelled;
    task.speed = 0;
    await _db.updateTask(task);
    onTaskUpdated(task);

    await _notifications.cancel(task.notificationId);
    checkQueue(allTasks);
  }

  Future<void> _cancelActiveStreams(String taskId) async {
    if (_activeSubscriptions.containsKey(taskId)) {
      await _activeSubscriptions[taskId]?.cancel();
      _activeSubscriptions.remove(taskId);
    }
    if (_activeSinks.containsKey(taskId)) {
      try {
        await _activeSinks[taskId]?.flush();
        await _activeSinks[taskId]?.close();
      } catch (_) {}
      _activeSinks.remove(taskId);
    }
    if (_activeClients.containsKey(taskId)) {
      _activeClients[taskId]?.close();
      _activeClients.remove(taskId);
    }
  }
}
