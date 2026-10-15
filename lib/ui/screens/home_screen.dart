import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import 'downloading_tab.dart';
import 'downloads_tab.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<DownloadingTabState> _downloadingKey = GlobalKey<DownloadingTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFloatingAction() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _downloadingKey.currentState?.pasteAndDownload();
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final activeCount = downloadProv.activeTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Downloads',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7925F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7925F6),
          indicatorWeight: 3,
          labelColor: const Color(0xFF7925F6),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Downloading'),
            Tab(text: 'Downloads'),
          ],
        ),
      ),
      floatingActionButton: settingsProv.floatingButtonEnabled
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7925F6),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_link_rounded, size: 20),
              label: const Text(
                'Paste & Download',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _onFloatingAction,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          DownloadingTab(key: _downloadingKey),
          const DownloadsTab(),
        ],
      ),
    );
  }
}
