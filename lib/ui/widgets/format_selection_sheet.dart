import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/media_format.dart';

class FormatSelectionSheet extends StatelessWidget {
  final MediaMetadata metadata;
  final void Function(MediaFormatOption option) onSelect;

  const FormatSelectionSheet({
    super.key,
    required this.metadata,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (metadata.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    metadata.thumbnailUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (metadata.duration != null)
                      Text(
                        Formatters.formatDuration(metadata.duration!),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Format',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: metadata.formats.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final format = metadata.formats[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF272738)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  tileColor: isDark
                      ? const Color(0xFF1D1D2D)
                      : const Color(0xFFF9FAFB),
                  leading: Icon(
                    format.isAudioOnly ? Icons.music_note : Icons.movie,
                    color: const Color(0xFF7925F6),
                  ),
                  title: Text(
                    format.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  trailing: format.sizeBytes != null
                      ? Text(
                          Formatters.formatBytes(format.sizeBytes!),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(format);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
