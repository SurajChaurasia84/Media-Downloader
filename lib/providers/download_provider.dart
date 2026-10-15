import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/utils/url_validator.dart';
import '../data/database/app_database.dart';
import '../data/models/download_task.dart';
import '../data/models/media_format.dart';
import '../data/preferences/settings_repository.dart';
import '../services/download_engine.dart';
import '../services/media_extractor.dart';

class DownloadProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  final MediaExtractor _extractor = MediaExtractor();
  final SettingsRepository _settings;
  late final DownloadEngine _engine;

  List<DownloadTask> _tasks = [];
  bool _isLoading = true;
  bool _isInspecting = false;
  String? _inspectError;
  MediaMetadata? _currentMetadata;
  bool _isVaultUnlocked = false;

  DownloadProvider(this._settings) {
    _engine = DownloadEngine(
      settings: _settings,
      onTaskUpdated: (task) {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = task;
        } else {
          _tasks.insert(0, task);
        }
        notifyListeners();
      },
    );
    loadTasks();
  }

  List<DownloadTask> get allTasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isInspecting => _isInspecting;
  String? get inspectError => _inspectError;
  MediaMetadata? get currentMetadata => _currentMetadata;
  bool get isVaultUnlocked => _isVaultUnlocked;

  List<DownloadTask> get activeTasks => _tasks.where((t) =>
      t.status == DownloadStatus.downloading ||
      t.status == DownloadStatus.preparing ||
      t.status == DownloadStatus.waiting ||
      t.status == DownloadStatus.paused ||
      t.status == DownloadStatus.finalizing).toList();

  List<DownloadTask> get completedTasks => _tasks.where((t) =>
      t.status == DownloadStatus.completed && !t.isPrivate).toList();

  List<DownloadTask> get privateCompletedTasks => _tasks.where((t) =>
      t.status == DownloadStatus.completed && t.isPrivate).toList();

  void unlockVault() {
    _isVaultUnlocked = true;
    notifyListeners();
  }

  void lockVault() {
    _isVaultUnlocked = false;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    _tasks = await _db.getAllTasks();

    // Reconcile interrupted tasks from last run
    for (final task in _tasks) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.preparing) {
        task.status = DownloadStatus.paused;
        await _db.updateTask(task);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<MediaMetadata?> inspectUrl(String url) async {
    if (!UrlValidator.isValidUrl(url)) {
      _inspectError = 'Invalid URL';
      notifyListeners();
      return null;
    }

    _isInspecting = true;
    _inspectError = null;
    _currentMetadata = null;
    notifyListeners();

    try {
      final meta = await _extractor.extractMetadata(url);
      _currentMetadata = meta;
      _isInspecting = false;
      notifyListeners();
      return meta;
    } catch (e) {
      _inspectError = 'Failed to load media info';
      _isInspecting = false;
      notifyListeners();
      return null;
    }
  }

  void clearCurrentMetadata() {
    _currentMetadata = null;
    _inspectError = null;
    notifyListeners();
  }

  Future<void> startDownload({
    required String url,
    required String title,
    required MediaFormatOption format,
    String? thumbnailUrl,
    bool? isPrivate,
  }) async {
    // Avoid starting duplicate if already running identical url
    final existing = _tasks.firstWhere(
      (t) => t.url == url && (t.status == DownloadStatus.downloading || t.status == DownloadStatus.waiting),
      orElse: () => DownloadTask(
        id: '',
        notificationId: 0,
        url: '',
        title: '',
        format: '',
        quality: '',
        filePath: '',
        createdAt: DateTime.now(),
      ),
    );
    if (existing.id.isNotEmpty) {
      return;
    }

    final task = await _engine.createTask(
      url: url,
      title: title,
      format: format,
      thumbnailUrl: thumbnailUrl,
      isPrivate: isPrivate,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _engine.checkQueue(_tasks);
  }

  Future<void> pause(DownloadTask task) async {
    await _engine.pauseDownload(task, _tasks);
  }

  Future<void> resume(DownloadTask task) async {
    await _engine.resumeDownload(task, _tasks);
  }

  Future<void> cancel(DownloadTask task) async {
    await _engine.cancelDownload(task, _tasks);
  }

  Future<void> retry(DownloadTask task) async {
    task.status = DownloadStatus.waiting;
    task.error = null;
    await _db.updateTask(task);
    notifyListeners();
    _engine.checkQueue(_tasks);
  }

  Future<void> deleteTask(DownloadTask task, {bool deleteActualFile = true}) async {
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.waiting) {
      await cancel(task);
    }

    if (deleteActualFile) {
      final file = File(task.filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final partFile = File('${task.filePath}.part');
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
    }

    await _db.deleteTask(task.id);
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
  }

  Future<void> togglePrivate(DownloadTask task) async {
    final currentFile = File(task.filePath);
    if (!await currentFile.exists()) {
      return;
    }

    final targetDir = task.isPrivate
        ? await _engine.getPublicDownloadDir()
        : await _engine.getPrivateDownloadDir();

    final fileName = p.basename(task.filePath);
    final targetPath = p.join(targetDir, fileName);

    await currentFile.rename(targetPath);

    task.filePath = targetPath;
    task.isPrivate = !task.isPrivate;
    await _db.updateTask(task);
    notifyListeners();
  }

  Future<void> clearCompletedHistory({bool deleteActualFiles = false}) async {
    await _db.clearCompletedHistory(deleteActualFiles: deleteActualFiles);
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }
}
