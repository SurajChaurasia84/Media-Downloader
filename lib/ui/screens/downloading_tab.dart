import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/download_card.dart';
import '../widgets/format_selection_sheet.dart';

class DownloadingTab extends StatefulWidget {
  const DownloadingTab({super.key});

  @override
  State<DownloadingTab> createState() => _DownloadingTabState();
}

class _DownloadingTabState extends State<DownloadingTab> {
  final TextEditingController _urlController = TextEditingController();

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
    }
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    final settingsProv = context.read<SettingsProvider>();

    final meta = await downloadProv.inspectUrl(url);
    if (!mounted) return;

    if (meta == null) {
      final error = downloadProv.inspectError ?? 'Invalid or unsupported URL';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (settingsProv.askBeforeDownload && meta.formats.length > 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FormatSelectionSheet(
          metadata: meta,
          onSelect: (selectedFormat) {
            downloadProv.startDownload(
              url: meta.url,
              title: meta.title,
              format: selectedFormat,
              thumbnailUrl: meta.thumbnailUrl,
            );
            _urlController.clear();
          },
        ),
      );
    } else {
      // Direct download with default preference
      final isAudio = settingsProv.defaultFormat == 'audio';
      final format = meta.formats.firstWhere(
        (f) => f.isAudioOnly == isAudio,
        orElse: () => meta.formats.first,
      );

      downloadProv.startDownload(
        url: meta.url,
        title: meta.title,
        format: format,
        thumbnailUrl: meta.thumbnailUrl,
      );
      _urlController.clear();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final activeTasks = downloadProv.activeTasks;
    final isInspecting = downloadProv.isInspecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // URL Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Paste URL here',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.link, size: 20),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _urlController.clear()),
                          )
                        : IconButton(
                            icon: const Icon(Icons.content_paste, size: 18),
                            onPressed: _pasteUrl,
                            tooltip: 'Paste',
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _handleDownload(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFF7925F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isInspecting ? null : _handleDownload,
                  child: isInspecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.arrow_downward, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Active Tasks List
          Expanded(
            child: activeTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No active downloads',
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: activeTasks.length,
                    itemBuilder: (context, index) {
                      final task = activeTasks[index];
                      return DownloadCard(
                        task: task,
                        onPause: () => downloadProv.pause(task),
                        onResume: () => downloadProv.resume(task),
                        onCancel: () => downloadProv.cancel(task),
                        onRetry: () => downloadProv.retry(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
