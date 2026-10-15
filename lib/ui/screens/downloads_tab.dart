import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/pin_service.dart';
import '../../data/models/download_task.dart';
import '../../providers/download_provider.dart';
import '../widgets/completed_file_card.dart';
import 'pin_dialog.dart';

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
  String _filter = 'all'; // 'all', 'video', 'audio', 'vault'
  String _searchQuery = '';
  bool _isSearching = false;

  void _openVault() async {
    final downloadProv = context.read<DownloadProvider>();
    final hasPin = await PinService.hasPin();

    if (!mounted) return;

    if (!hasPin) {
      showDialog(
        context: context,
        builder: (_) => PinDialog(
          isSettingPin: true,
          onSuccess: () {
            downloadProv.unlockVault();
            setState(() => _filter = 'vault');
          },
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => PinDialog(
          isSettingPin: false,
          onSuccess: () {
            downloadProv.unlockVault();
            setState(() => _filter = 'vault');
          },
        ),
      );
    }
  }

  void _confirmDelete(DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DownloadProvider>().deleteTask(task, deleteActualFile: true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadProv = context.watch<DownloadProvider>();

    final isVault = _filter == 'vault';
    final isLocked = isVault && !downloadProv.isVaultUnlocked;

    List<DownloadTask> tasks = isVault
        ? downloadProv.privateCompletedTasks
        : downloadProv.completedTasks;

    if (_filter == 'video') {
      tasks = tasks.where((t) => t.format == 'video').toList();
    } else if (_filter == 'audio') {
      tasks = tasks.where((t) => t.format == 'audio').toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Filter Chips & Search Toggle
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('all', 'All'),
                      const SizedBox(width: 6),
                      _buildChip('video', 'Videos'),
                      const SizedBox(width: 6),
                      _buildChip('audio', 'Audio'),
                      const SizedBox(width: 6),
                      _buildChip('vault', 'Vault', isLock: true),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, size: 20),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchQuery = '';
                  });
                },
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search files...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ],
          const SizedBox(height: 12),
          // Content
          Expanded(
            child: isLocked
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vault is Locked',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7925F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _openVault,
                          icon: const Icon(Icons.key, size: 18),
                          label: const Text('Unlock Vault'),
                        ),
                      ],
                    ),
                  )
                : tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isVault ? 'Vault is empty' : 'No downloads yet',
                              style: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return CompletedFileCard(
                            task: task,
                            onTogglePrivate: () => downloadProv.togglePrivate(task),
                            onDelete: () => _confirmDelete(task),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, {bool isLock = false}) {
    final isSelected = _filter == key;
    return ChoiceChip(
      avatar: isLock
          ? Icon(
              Icons.lock,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF7925F6),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: const Color(0xFF7925F6),
      showCheckmark: false,
      onSelected: (_) {
        if (key == 'vault') {
          final downloadProv = context.read<DownloadProvider>();
          if (!downloadProv.isVaultUnlocked) {
            _openVault();
            return;
          }
        }
        setState(() => _filter = key);
      },
    );
  }
}
