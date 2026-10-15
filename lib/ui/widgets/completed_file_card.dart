import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/download_task.dart';

class CompletedFileCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onTogglePrivate;
  final VoidCallback onDelete;

  const CompletedFileCard({
    super.key,
    required this.task,
    required this.onTogglePrivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final file = File(task.filePath);
    final fileExists = file.existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: fileExists
            ? () => OpenFilex.open(task.filePath)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File not found on device')),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: isDark ? const Color(0xFF26263A) : const Color(0xFFEDE8FF),
                  child: task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          task.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            task.format == 'audio' ? Icons.music_note : Icons.movie,
                            color: const Color(0xFF7925F6),
                            size: 24,
                          ),
                        )
                      : Icon(
                          task.format == 'audio' ? Icons.music_note : Icons.movie,
                          color: const Color(0xFF7925F6),
                          size: 24,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: fileExists ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.formatBytes(task.downloadedBytes),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          task.completedAt != null
                              ? Formatters.formatDate(task.completedAt!)
                              : Formatters.formatDate(task.createdAt),
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
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                color: const Color(0xFF7925F6),
                onPressed: fileExists ? () => OpenFilex.open(task.filePath) : null,
                tooltip: 'Play',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (val) {
                  if (val == 'share') {
                    if (fileExists) {
                      SharePlus.instance.share(ShareParams(files: [XFile(task.filePath)]));
                    }
                  } else if (val == 'private') {
                    onTogglePrivate();
                  } else if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 18),
                        SizedBox(width: 10),
                        Text('Share'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'private',
                    child: Row(
                      children: [
                        Icon(
                          task.isPrivate ? Icons.lock_open : Icons.lock,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(task.isPrivate ? 'Make Public' : 'Move to Private'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
