import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 1;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }

  Future<void> scheduleCollectionReminder({
    required String customerName,
    required DateTime fromDate,
  }) async {
    if (!_initialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    final target = tz.TZDateTime(
      tz.local,
      fromDate.year,
      fromDate.month,
      fromDate.day + 15,
      8,
      0,
      0,
    );

    final scheduled = target.isAfter(now) ? target : now.add(const Duration(seconds: 5));

    const androidDetails = AndroidNotificationDetails(
      'cartera_reminder_channel',
      'Recordatorios de cobro',
      channelDescription:
          'Notifica cuando se cumplen 15 dias desde el ultimo abono de una clienta',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final id = _nextId++;

    await _plugin.zonedSchedule(
      id: id,
      title: 'Recuerda cobrarle a $customerName',
      body: 'Han pasado 15 dias desde el ultimo abono. Pasa a cobrar.',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exact,
      payload: customerName,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
