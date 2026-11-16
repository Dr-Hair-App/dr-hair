import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Pure Hive typed facade for app data that survives restarts.
class AppLocalCache {
  AppLocalCache._({this._box, this._memoryStore});

  static const String boxName = 'dr_hair_cache';
  static Box<dynamic>? _sharedBox;
  static final Map<String, Object?> _fallbackMemoryStore = <String, Object?>{};

  final Box<dynamic>? _box;
  final Map<String, Object?>? _memoryStore;

  static AppLocalCache get instance =>
      AppLocalCache._(box: _sharedBox, memoryStore: _sharedBox == null ? _fallbackMemoryStore : null);

  @visibleForTesting
  factory AppLocalCache.inMemory([Map<String, Object?>? values]) =>
      AppLocalCache._(memoryStore: values ?? <String, Object?>{});

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _sharedBox = await Hive.openBox<dynamic>(boxName);
  }

  Object? get(String key) => _box?.get(key) ?? _memoryStore?[key];

  String? getString(String key) => get(key) as String?;

  bool? getBool(String key) => get(key) as bool?;

  int? getInt(String key, [int? defaultValue]) {
    final val = get(key);
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  double? getDouble(String key, [double? defaultValue]) {
    final val = get(key);
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  dynamic getJson(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> putJson(String key, dynamic value) async {
    await put(key, jsonEncode(value));
  }

  bool containsKey(String key) =>
      _box?.containsKey(key) ?? _memoryStore?.containsKey(key) ?? false;

  Future<void> put(String key, Object value) async {
    if (_box != null) {
      await _box.put(key, value);
    } else {
      _memoryStore?[key] = value;
    }
  }

  Future<void> remove(String key) async {
    if (_box != null) {
      await _box.delete(key);
    } else {
      _memoryStore?.remove(key);
    }
  }

  /// Generates a namespaced key for patient-specific state.
  static String patientKey(String patientId, String key) {
    final cleanId = patientId.trim();
    return cleanId.isNotEmpty ? 'patient_${cleanId}_$key' : key;
  }

  /// Removes all persisted keys belonging specifically to the given patient.
  Future<void> clearPatientScopedData(String patientId) async {
    final cleanId = patientId.trim();
    if (cleanId.isEmpty) return;
    final prefix = 'patient_${cleanId}_';

    final box = _box;
    if (box != null) {
      final keysToRemove = box.keys
          .map((k) => k.toString())
          .where((k) => k.startsWith(prefix) || k.contains(cleanId))
          .toList();
      for (final key in keysToRemove) {
        await box.delete(key);
      }
    }
    final memoryStore = _memoryStore;
    if (memoryStore != null) {
      memoryStore.removeWhere((k, _) => k.startsWith(prefix) || k.contains(cleanId));
    }
  }

  /// Clears app-persisted user state directly from Hive.
  Future<void> clearAll() async {
    if (_box != null) {
      await _box.clear();
    } else {
      _memoryStore?.clear();
    }
  }
}
