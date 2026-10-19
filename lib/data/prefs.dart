import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../engine/models.dart';
import '../engine/quiet_hours.dart';

/// Concrete [PrefsStore] backed by a JSON file in the app documents dir.
/// Use [PrefsStore.inMemory()] in tests.
abstract interface class PrefsStore {
  Future<ReminderProfile> getProfile();
  Future<void> setProfile(ReminderProfile profile);
  Future<QuietHours> getQuietHours();
  Future<void> setQuietHours(QuietHours h);
  Future<String> getUserTimezone();
  Future<void> setUserTimezone(String z);
  Future<bool> isExactAlarmGranted();
  Future<void> setExactAlarmGranted(bool g);

  factory PrefsStore.inMemory() = _InMemoryPrefs;
}

// ─── In-memory implementation (for tests and first-run) ──────────────────────

class _InMemoryPrefs implements PrefsStore {
  ReminderProfile _profile = ReminderProfile.standard;
  QuietHours _quiet = QuietHours.none;
  String _tz = 'UTC';
  bool _exactAlarm = false;

  @override
  Future<ReminderProfile> getProfile() async => _profile;
  @override
  Future<void> setProfile(ReminderProfile profile) async => _profile = profile;
  @override
  Future<QuietHours> getQuietHours() async => _quiet;
  @override
  Future<void> setQuietHours(QuietHours h) async => _quiet = h;
  @override
  Future<String> getUserTimezone() async => _tz;
  @override
  Future<void> setUserTimezone(String z) async => _tz = z;
  @override
  Future<bool> isExactAlarmGranted() async => _exactAlarm;
  @override
  Future<void> setExactAlarmGranted(bool g) async => _exactAlarm = g;
}

// ─── File-backed implementation ───────────────────────────────────────────────

class FilePrefsStore implements PrefsStore {
  FilePrefsStore._();

  static FilePrefsStore? _instance;

  static Future<FilePrefsStore> open() async {
    _instance ??= FilePrefsStore._();
    return _instance!;
  }

  Map<String, dynamic> _cache = {};
  bool _loaded = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'prefs.json'));
  }

  Future<Map<String, dynamic>> _load() async {
    if (_loaded) return _cache;
    final f = await _file();
    if (f.existsSync()) {
      try {
        _cache = json.decode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        _cache = {};
      }
    }
    _loaded = true;
    return _cache;
  }

  Future<void> _save() async {
    final f = await _file();
    await f.writeAsString(json.encode(_cache));
  }

  @override
  Future<ReminderProfile> getProfile() async {
    final data = await _load();
    return ReminderProfile.byId(data['profile'] as String? ?? 'standard');
  }

  @override
  Future<void> setProfile(ReminderProfile profile) async {
    (await _load())['profile'] = profile.id;
    await _save();
  }

  @override
  Future<QuietHours> getQuietHours() async {
    final data = await _load();
    final enabled = data['qh_enabled'] as bool? ?? false;
    final start = data['qh_start'] as int? ?? 1380; // 23:00
    final end = data['qh_end'] as int? ?? 420; // 07:00
    return QuietHours(startMinute: start, endMinute: end, enabled: enabled);
  }

  @override
  Future<void> setQuietHours(QuietHours h) async {
    final data = await _load();
    data['qh_enabled'] = h.enabled;
    data['qh_start'] = h.startMinute;
    data['qh_end'] = h.endMinute;
    await _save();
  }

  @override
  Future<String> getUserTimezone() async {
    final data = await _load();
    return data['timezone'] as String? ?? 'UTC';
  }

  @override
  Future<void> setUserTimezone(String z) async {
    (await _load())['timezone'] = z;
    await _save();
  }

  @override
  Future<bool> isExactAlarmGranted() async {
    final data = await _load();
    return data['exact_alarm'] as bool? ?? false;
  }

  @override
  Future<void> setExactAlarmGranted(bool g) async {
    (await _load())['exact_alarm'] = g;
    await _save();
  }
}
