import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/app_local_cache.dart';
import '../../domain/models/care_models.dart';

enum NotificationPermissionStatus {
  notDetermined,
  granted,
  denied,
  unavailable,
}

/// Service managing reminder notification scheduling, permissions, and persistence.
class CareNotificationService {
  static const String _remindersStorageKey = 'care_persisted_reminders_v1';
  static const String _routineStorageKey = 'care_persisted_routine_v1';
  static const String _routineDayKey = 'care_persisted_routine_day_v1';

  final AppLocalCache? _cache;

  CareNotificationService([this._cache]);

  static Future<CareNotificationService> create() async {
    try {
      return CareNotificationService(AppLocalCache.instance);
    } catch (e) {
      debugPrint('CareNotificationService init fallback: $e');
      return CareNotificationService();
    }
  }

  /// Retrieves the current notification permission status.
  NotificationPermissionStatus getPermissionStatus() {
    return NotificationPermissionStatus.unavailable;
  }

  /// No native notification plugin is configured in this build, so do not
  /// display or persist a simulated permission result.
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unavailable;

  /// Persists the active list of reminders to local storage.
  Future<bool> saveReminders(List<CareReminder> reminders) async {
    if (_cache == null) return false;
    try {
      final jsonList = reminders.map((r) => r.toJson()).toList();
      await _cache.put(_remindersStorageKey, jsonEncode(jsonList));
      return true;
    } catch (e) {
      debugPrint('Failed to save reminders: $e');
      return false;
    }
  }

  /// Loads persisted reminders from local storage.
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

  /// Persists routine tasks to local storage.
  Future<bool> saveRoutineTasks(List<RoutineTask> tasks) async {
    if (_cache == null) return false;
    try {
      final jsonList = tasks.map((t) => t.toJson()).toList();
      await _cache.put(_routineStorageKey, jsonEncode(jsonList));
      return true;
    } catch (e) {
      debugPrint('Failed to save routine tasks: $e');
      return false;
    }
  }

  /// Loads persisted routine tasks from local storage.
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
      debugPrint('Failed to load routine tasks: $e');
      return null;
    }
  }

  String? loadRoutineDay() => _cache?.getString(_routineDayKey);

  Future<void> saveRoutineDay(String day) async {
    await _cache?.put(_routineDayKey, day);
  }

  /// Schedules a notification for a reminder without duplicates.
  Future<void> scheduleReminder(CareReminder reminder) async {
    // In production without native notification plugins bundled in pubspec,
    // we log scheduling and track state. Native platform requirements:
    // Android: android.permission.POST_NOTIFICATIONS, ExactAlarm permission
    // iOS: UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    debugPrint(
      '[CareNotificationService] Saved reminder "${reminder.title}"; timed alerts are unavailable in this build.',
    );
  }

  /// Cancels a scheduled reminder notification.
  Future<void> cancelReminder(String reminderId) async {
    debugPrint(
      '[CareNotificationService] Removed reminder $reminderId; no native alert was scheduled.',
    );
  }
}
