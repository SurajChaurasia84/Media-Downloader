import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import 'pin_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final downloadProv = context.watch<DownloadProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Downloads
          _buildSectionHeader('Downloads'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Simultaneous downloads', style: TextStyle(fontSize: 14)),
                  trailing: DropdownButton<int>(
                    value: settingsProv.maxConcurrentDownloads,
                    underline: const SizedBox(),
                    items: [1, 2, 3, 4, 5].map((val) {
                      return DropdownMenuItem(value: val, child: Text('$val'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsProv.setMaxConcurrentDownloads(val);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Ask format before download', style: TextStyle(fontSize: 14)),
                  value: settingsProv.askBeforeDownload,
                  onChanged: settingsProv.setAskBeforeDownload,
                  activeThumbColor: const Color(0xFF7925F6),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Default format', style: TextStyle(fontSize: 14)),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'video', label: Text('Video')),
                      ButtonSegment(value: 'audio', label: Text('Audio')),
                    ],
                    selected: {settingsProv.defaultFormat},
                    onSelectionChanged: (set) => settingsProv.setDefaultFormat(set.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Default quality', style: TextStyle(fontSize: 14)),
                  trailing: DropdownButton<String>(
                    value: settingsProv.defaultQuality,
                    underline: const SizedBox(),
                    items: ['Best', '1080p', '720p', '480p'].map((q) {
                      return DropdownMenuItem(value: q, child: Text(q));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsProv.setDefaultQuality(val);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Save location', style: TextStyle(fontSize: 14)),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'public', label: Text('Public')),
                      ButtonSegment(value: 'private', label: Text('Private')),
                    ],
                    selected: {settingsProv.defaultLocation},
                    onSelectionChanged: (set) => settingsProv.setDefaultLocation(set.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Floating button', style: TextStyle(fontSize: 14)),
                  value: settingsProv.floatingButtonEnabled,
                  onChanged: settingsProv.setFloatingButtonEnabled,
                  activeThumbColor: const Color(0xFF7925F6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Notifications
          _buildSectionHeader('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Progress notifications', style: TextStyle(fontSize: 14)),
                  value: settingsProv.progressNotifications,
                  onChanged: settingsProv.setProgressNotifications,
                  activeThumbColor: const Color(0xFF7925F6),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Completion notifications', style: TextStyle(fontSize: 14)),
                  value: settingsProv.completionNotifications,
                  onChanged: settingsProv.setCompletionNotifications,
                  activeThumbColor: const Color(0xFF7925F6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Privacy & PIN
          _buildSectionHeader('Privacy'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined, color: Color(0xFF7925F6)),
              title: const Text('Security PIN', style: TextStyle(fontSize: 14)),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PinScreen(
                        isSettingPin: true,
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN updated successfully')),
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Set / Change'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Storage
          _buildSectionHeader('Storage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline, color: Color(0xFF7925F6)),
                  title: const Text('Storage used', style: TextStyle(fontSize: 14)),
                  trailing: Text(
                    Formatters.formatBytes(settingsProv.totalStorageUsed),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  title: const Text('Clear completed history', style: TextStyle(fontSize: 14)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Clear History?', style: TextStyle(fontSize: 16)),
                        content: const Text('Completed download records will be cleared. Keep downloaded files?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              downloadProv.clearCompletedHistory(deleteActualFiles: true);
                              settingsProv.calculateStorageUsed();
                            },
                            child: const Text('Delete Files', style: TextStyle(color: Colors.redAccent)),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              downloadProv.clearCompletedHistory(deleteActualFiles: false);
                            },
                            child: const Text('Keep Files'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Theme
          _buildSectionHeader('Appearance'),
          Card(
            child: ListTile(
              title: const Text('Theme', style: TextStyle(fontSize: 14)),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Auto')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {settingsProv.themeModeString},
                onSelectionChanged: (set) => settingsProv.setThemeMode(set.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7925F6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
