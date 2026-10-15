import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/download_task.dart';

class DownloadCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;

  const DownloadCard({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    switch (task.status) {
      case DownloadStatus.downloading:
        statusColor = const Color(0xFF7925F6);
        statusText = 'Downloading';
        break;
      case DownloadStatus.paused:
        statusColor = Colors.orange;
        statusText = 'Paused';
        break;
      case DownloadStatus.waiting:
        statusColor = Colors.blueGrey;
        statusText = 'Waiting';
        break;
      case DownloadStatus.preparing:
        statusColor = Colors.teal;
        statusText = 'Preparing';
        break;
      case DownloadStatus.finalizing:
        statusColor = Colors.indigo;
        statusText = 'Finalizing';
        break;
      case DownloadStatus.failed:
        statusColor = Colors.redAccent;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = task.status.name;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: isDark ? const Color(0xFF26263A) : const Color(0xFFEDE8FF),
                    child: task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            task.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              task.format == 'audio' ? Icons.music_note : Icons.movie,
                              color: const Color(0xFF7925F6),
                              size: 22,
                            ),
                          )
                        : Icon(
                            task.format == 'audio' ? Icons.music_note : Icons.movie,
                            color: const Color(0xFF7925F6),
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.quality,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (task.status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_filled, size: 28),
                    color: const Color(0xFF7925F6),
                    onPressed: onPause,
                    tooltip: 'Pause',
                  )
                else if (task.status == DownloadStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_circle_filled, size: 28),
                    color: const Color(0xFF7925F6),
                    onPressed: onResume,
                    tooltip: 'Resume',
                  )
                else if (task.status == DownloadStatus.failed && onRetry != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 24),
                    color: Colors.redAccent,
                    onPressed: onRetry,
                    tooltip: 'Retry',
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey,
                  onPressed: onCancel,
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: task.totalBytes != null && task.totalBytes! > 0
                  ? LinearProgressIndicator(
                      value: task.progress,
                      backgroundColor: isDark
                          ? const Color(0xFF26263A)
                          : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF7925F6)),
                      minHeight: 5,
                    )
                  : const LinearProgressIndicator(
                      backgroundColor: Color(0xFF26263A),
                      valueColor: AlwaysStoppedAnimation(Color(0xFF7925F6)),
                      minHeight: 5,
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.totalBytes != null
                      ? '${task.percentage}% • ${Formatters.formatBytes(task.downloadedBytes)} / ${Formatters.formatBytes(task.totalBytes!)}'
                      : Formatters.formatBytes(task.downloadedBytes),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.status == DownloadStatus.downloading && task.speed > 0)
                  Text(
                    Formatters.formatSpeed(task.speed),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7925F6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
