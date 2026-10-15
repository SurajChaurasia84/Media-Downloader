import 'dart:async';
import 'package:flutter/services.dart';
import '../data/models/media_format.dart';

class YtDlpService {
  static const MethodChannel _channel = MethodChannel('com.downloads.app/ytdlp');

  static bool _initialized = false;
  static final Map<String, void Function(double progress, String line)> _progressListeners = {};

  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDownloadProgress') {
        final args = call.arguments as Map?;
        if (args != null) {
          final taskId = args['taskId'] as String?;
          final progress = (args['progress'] as num?)?.toDouble() ?? 0.0;
          final line = args['line'] as String? ?? '';
          if (taskId != null && _progressListeners.containsKey(taskId)) {
            _progressListeners[taskId]!(progress, line);
          }
        }
      }
    });
  }

  static Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<MediaMetadata?> extractInfo(String url) async {
    init();
    try {
      final res = await _channel.invokeMethod<Map>('extractInfo', {'url': url});
      if (res == null) return null;

      final title = (res['title'] as String?)?.trim() ?? 'Video';
      final duration = (res['duration'] as num?)?.toInt() ?? 0;
      final thumbnail = res['thumbnail'] as String?;
      final uploader = res['uploader'] as String?;
      final defaultExt = (res['ext'] as String?) ?? 'mp4';
      final directStreamUrl = res['url'] as String?;

      final rawFormats = res['formats'] as List? ?? [];
      final formatOptions = <MediaFormatOption>[];

      for (final f in rawFormats) {
        if (f is Map) {
          final formatId = f['formatId'] as String? ?? '';
          final ext = f['ext'] as String? ?? defaultExt;
          final note = f['formatNote'] as String? ?? '';
          final fileSize = (f['fileSize'] as num?)?.toInt();
          final streamUrl = f['url'] as String? ?? '';
          final vcodec = f['vcodec'] as String? ?? '';
          final acodec = f['acodec'] as String? ?? '';
          final height = (f['height'] as num?)?.toInt() ?? 0;

          final isAudioOnly = vcodec == 'none' || (vcodec.isEmpty && acodec.isNotEmpty && acodec != 'none');
          var label = '';
          if (isAudioOnly) {
            label = 'Audio ($ext) ${note.isNotEmpty ? '• $note' : ''}'.trim();
          } else {
            label = '${height > 0 ? '${height}p ' : ''}($ext) ${note.isNotEmpty ? '• $note' : ''}'.trim();
          }

          if (label.isEmpty) {
            label = '$ext format $formatId';
          }

          formatOptions.add(
            MediaFormatOption(
              id: streamUrl.isNotEmpty ? streamUrl : formatId,
              label: label,
              extension: ext,
              sizeBytes: fileSize,
              isAudioOnly: isAudioOnly,
            ),
          );
        }
      }

      // If no separate formats were listed, add default direct stream
      if (formatOptions.isEmpty) {
        formatOptions.add(
          MediaFormatOption(
            id: directStreamUrl?.isNotEmpty == true ? directStreamUrl! : url,
            label: 'Default ($defaultExt)',
            extension: defaultExt,
            sizeBytes: null,
            isAudioOnly: false,
          ),
        );
      }

      return MediaMetadata(
        url: url,
        title: title,
        author: uploader,
        duration: duration > 0 ? Duration(seconds: duration) : null,
        thumbnailUrl: thumbnail,
        formats: formatOptions,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<bool> downloadWithYtDlp({
    required String url,
    required String outputPath,
    String? format,
    required String taskId,
    required void Function(double progress, String line) onProgress,
  }) async {
    init();
    _progressListeners[taskId] = onProgress;
    try {
      final res = await _channel.invokeMethod<bool>('downloadWithYtDlp', {
        'url': url,
        'outputPath': outputPath,
        'format': format,
        'taskId': taskId,
      });
      return res ?? false;
    } finally {
      _progressListeners.remove(taskId);
    }
  }
}
