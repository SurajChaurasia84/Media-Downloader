import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          OpenFilex.open(payload);
        }
      },
    );

    _initialized = true;
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    required String body,
    bool indeterminate = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'downloads_progress_channel',
      'Download Progress',
      channelDescription: 'Active media downloads',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: indeterminate ? 0 : progress,
      indeterminate: indeterminate,
      ongoing: true,
      autoCancel: false,
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? filePath,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'downloads_complete_channel',
      'Completed Downloads',
      channelDescription: 'Finished media downloads',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: filePath,
    );
  }

  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
