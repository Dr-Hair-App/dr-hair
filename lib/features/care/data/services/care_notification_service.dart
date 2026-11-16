import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/routes/app_destination.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../../domain/models/care_models.dart';

enum NotificationPermissionStatus {
  notDetermined,
  granted,
  denied,
  unavailable,
}

/// Schedules patient-selected care alerts on the device.
class CareNotificationService {
  static const String actionRoutineTaken = 'ACTION_ROUTINE_TAKEN';
  static const String actionRoutineSnooze = 'ACTION_ROUTINE_SNOOZE';
  static const String categoryRoutine = 'CARE_ROUTINE_REMINDER';

  static const String _remindersStorageKey = 'care_persisted_reminders_v1';
  static const String _routineStorageKey = 'care_persisted_routine_v1';
  static const String _routineDayKey = 'care_persisted_routine_day_v1';
  static const int _reminderIdBase = 710000;

  final AppLocalCache? _cache;
  final FlutterLocalNotificationsPlugin _plugin;
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  bool _initialized = false;

  CareNotificationService([this._cache])
    : _plugin = FlutterLocalNotificationsPlugin();

  static Future<CareNotificationService> create() async {
    CareNotificationService service;
    try {
      service = CareNotificationService(AppLocalCache.instance);
    } catch (e) {
      debugPrint('CareNotificationService init fallback: $e');
      service = CareNotificationService();
    }
    await service.initialize();
    return service;
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        _permissionStatus = NotificationPermissionStatus.unavailable;
      }
      return;
    }

    try {
      tz_data.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final location = AppDestination.resolveSafeLocation(
            response.payload,
            fallback: RouteNames.reminders,
          );
          AppRouter.router.push(location);
        },
      );
      _initialized = true;
      await _refreshPermissionStatus();
    } catch (e) {
      _permissionStatus = NotificationPermissionStatus.unavailable;
      debugPrint('Care notification initialization failed: $e');
    }
  }

  NotificationPermissionStatus getPermissionStatus() => _permissionStatus;

  Future<void> _refreshPermissionStatus() async {
    if (!_initialized) return;
    try {
      bool? granted;
      if (Platform.isAndroid) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
      } else if (Platform.isIOS) {
        final permissions = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        granted = permissions?.isEnabled;
      }
      _permissionStatus = granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.notDetermined;
    } catch (_) {
      _permissionStatus = NotificationPermissionStatus.unavailable;
    }
  }

  /// Requests OS permission only after the patient chooses to enable alerts.
  Future<NotificationPermissionStatus> requestPermission() async {
    await initialize();
    if (!_initialized) return _permissionStatus;
    try {
      bool? granted;
      if (Platform.isAndroid) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      _permissionStatus = granted == null
          ? NotificationPermissionStatus.unavailable
          : granted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
      return _permissionStatus;
    } catch (e) {
      debugPrint('Care notification permission request failed: $e');
      _permissionStatus = NotificationPermissionStatus.unavailable;
      return _permissionStatus;
    }
  }

  Future<bool> saveReminders(List<CareReminder> reminders) async {
    if (_cache == null) return false;
    try {
      await _cache.put(
        _remindersStorageKey,
        jsonEncode(reminders.map((r) => r.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('Failed to save reminders: $e');
      return false;
    }
  }

  List<CareReminder>? loadReminders() {
    if (_cache == null) return null;
    final raw = _cache.getString(_remindersStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => CareReminder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load persisted reminders: $e');
      return null;
    }
  }

  Future<void> syncScheduledReminders(List<CareReminder> reminders) async {
    await initialize();
    if (!_initialized ||
        _permissionStatus != NotificationPermissionStatus.granted) {
      return;
    }
    for (final reminder in reminders) {
      if (reminder.isEnabled) {
        await scheduleReminder(reminder);
      } else {
        await cancelReminder(reminder.id);
      }
    }
  }

  Future<void> scheduleReminder(CareReminder reminder) async {
    await initialize();
    if (!_initialized ||
        _permissionStatus != NotificationPermissionStatus.granted) {
      return;
    }
    await cancelReminder(reminder.id);
    if (!reminder.isEnabled) return;

    final days =
        reminder.repeatDays
            .toSet()
            .where((day) => day >= 1 && day <= 7)
            .toList()
          ..sort();
    if (days.isEmpty) return;

    for (final weekday in days) {
      final scheduledDate = _nextOccurrence(weekday, reminder.time);
      await _plugin.zonedSchedule(
        id: _notificationId(reminder.id, weekday),
        title: reminder.title,
        body: reminder.subtitle.isNotEmpty
            ? reminder.subtitle
            : 'Time for your care routine.',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders',
            'Care reminders',
            channelDescription: 'Patient scheduled hair care reminders.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: RouteNames.reminders,
      );
    }

    final snoozeTime = reminder.snoozedUntil;
    if (snoozeTime != null && snoozeTime.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _notificationId(reminder.id, 0),
        title: reminder.title,
        body: 'Snoozed care reminder',
        scheduledDate: tz.TZDateTime.from(snoozeTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders',
            'Care reminders',
            channelDescription: 'Patient scheduled hair care reminders.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: RouteNames.reminders,
      );
    }
  }

  tz.TZDateTime _nextOccurrence(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var daysAhead = (weekday - now.weekday) % 7;
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysAhead,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  int _notificationId(String reminderId, int weekday) {
    var hash = 0;
    for (final unit in reminderId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _reminderIdBase + ((hash * 7 + weekday) % 100000000);
  }

  Future<void> cancelReminder(String reminderId) async {
    if (!_initialized) return;
    for (var weekday = 0; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _notificationId(reminderId, weekday));
    }
  }

  Future<bool> saveRoutineTasks(List<RoutineTask> tasks) async {
    if (_cache == null) return false;
    try {
      await _cache.put(
        _routineStorageKey,
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('Failed to save routine tasks: $e');
      return false;
    }
  }

  List<RoutineTask>? loadRoutineTasks() {
    if (_cache == null) return null;
    final raw = _cache.getString(_routineStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => RoutineTask.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load persisted routine tasks: $e');
      return null;
    }
  }

  String? loadRoutineDay() => _cache?.getString(_routineDayKey);

  Future<void> saveRoutineDay(String day) async =>
      _cache?.put(_routineDayKey, day);
}
