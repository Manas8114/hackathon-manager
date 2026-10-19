import '../engine/models.dart';
import '../engine/quiet_hours.dart';
import '../data/prefs.dart';

class InMemoryPrefs implements PrefsStore {
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
