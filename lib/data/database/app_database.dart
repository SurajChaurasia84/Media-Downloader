import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/download_task.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'downloads_app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            notification_id INTEGER,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            thumbnail_url TEXT,
            format TEXT NOT NULL,
            quality TEXT NOT NULL,
            file_path TEXT NOT NULL,
            downloaded_bytes INTEGER NOT NULL,
            total_bytes INTEGER,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            is_private INTEGER NOT NULL DEFAULT 0,
            duration_seconds INTEGER,
            error TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN duration_seconds INTEGER');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> insertTask(DownloadTask task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(DownloadTask task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DownloadTask>> getAllTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'created_at DESC');
    return maps.map((m) => DownloadTask.fromMap(m)).toList();
  }

  Future<void> clearCompletedHistory({bool deleteActualFiles = false}) async {
    final db = await database;
    if (deleteActualFiles) {
      final maps = await db.query(
        'tasks',
        where: 'status = ?',
        whereArgs: [DownloadStatus.completed.name],
      );
      for (final m in maps) {
        final path = m['file_path'] as String?;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    }
    await db.delete(
      'tasks',
      where: 'status = ?',
      whereArgs: [DownloadStatus.completed.name],
    );
  }
}
