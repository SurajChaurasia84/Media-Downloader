import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/preferences/settings_repository.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.init();

  // Request notification permission on Android 13+
  await Permission.notification.request();

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(settingsRepo)),
        ChangeNotifierProvider(create: (_) => DownloadProvider(settingsRepo)),
      ],
      child: const DownloadsApp(),
    ),
  );
}

class DownloadsApp extends StatelessWidget {
  const DownloadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Downloads',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProv.themeMode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? const Color(0xFF0F0F17) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
