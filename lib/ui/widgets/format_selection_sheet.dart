import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/media_format.dart';
import '../../providers/settings_provider.dart';

class FormatSelectionSheet extends StatefulWidget {
  final MediaMetadata metadata;
  final void Function(MediaFormatOption option, bool isPrivate) onSelect;

  const FormatSelectionSheet({
    super.key,
    required this.metadata,
    required this.onSelect,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  String _filter = 'all'; // 'all', 'video', 'audio'
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _isPrivate = settings.defaultLocation == 'private';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final filteredFormats = widget.metadata.formats.where((f) {
      if (_filter == 'video') return !f.isAudioOnly;
      if (_filter == 'audio') return f.isAudioOnly;
      return true;
    }).toList();

    return Material(
      color: isDark ? const Color(0xFF161622) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Media Thumbnail & Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.metadata.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.metadata.thumbnailUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      color: isDark ? const Color(0xFF26263A) : const Color(0xFFE5E7EB),
                      child: const Icon(Icons.movie, size: 28),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.metadata.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.metadata.duration != null) ...[
                          Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            Formatters.formatDuration(widget.metadata.duration!),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          '${widget.metadata.formats.length} formats',
                          style: TextStyle(
                            fontSize: 12,
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters & Private Switch Row
          Row(
            children: [
              // Filter Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTab('all', 'All'),
                      const SizedBox(width: 6),
                      _buildTab('video', 'Video'),
                      const SizedBox(width: 6),
                      _buildTab('audio', 'Audio'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Save to Private Toggle
              InkWell(
                onTap: () => setState(() => _isPrivate = !_isPrivate),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPrivate ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: _isPrivate ? primary : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isPrivate ? FontWeight.bold : FontWeight.normal,
                          color: _isPrivate ? primary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Format List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredFormats.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final format = filteredFormats[index];
                return Material(
                  color: isDark ? const Color(0xFF1D1D2D) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF272738) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    tileColor: Colors.transparent,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: primary.withValues(alpha: 0.12),
                      child: Icon(
                        format.isAudioOnly ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                        color: primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      format.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (format.sizeBytes != null)
                          Text(
                            Formatters.formatBytes(format.sizeBytes!),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.download_rounded, size: 20, color: primary),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(format, _isPrivate);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTab(String key, String label) {
    final isSelected = _filter == key;
    final primary = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = key),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: primary,
      showCheckmark: false,
    );
  }
}
