import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/quiet_hours.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  ReminderProfile _profile = ReminderProfile.standard;
  QuietHours _quietHours = QuietHours.none;
  String _userTimezone = 'UTC';
  bool _exactAlarm = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(prefsProvider);
    final p = await prefs.getProfile();
    final q = await prefs.getQuietHours();
    final tz = await prefs.getUserTimezone();
    final exact = await prefs.isExactAlarmGranted();
    if (mounted) {
      setState(() {
        _profile = p;
        _quietHours = q;
        _userTimezone = tz;
        _exactAlarm = exact;
        _loaded = true;
      });
    }
  }

  Future<void> _setProfile(ReminderProfile p) async {
    setState(() => _profile = p);
    final prefs = ref.read(prefsProvider);
    await prefs.setProfile(p);
    final scheduler = ref.read(schedulerProvider);
    await scheduler.planAll();
  }

  Future<void> _toggleQuietHours(bool enabled) async {
    final updated = QuietHours(
      startMinute: _quietHours.startMinute == 0 && _quietHours.endMinute == 0 ? 22 * 60 : _quietHours.startMinute,
      endMinute: _quietHours.startMinute == 0 && _quietHours.endMinute == 0 ? 8 * 60 : _quietHours.endMinute,
      enabled: enabled,
    );
    setState(() => _quietHours = updated);
    final prefs = ref.read(prefsProvider);
    await prefs.setQuietHours(updated);
  }

  Future<void> _setTimezone(String tz) async {
    setState(() => _userTimezone = tz);
    final prefs = ref.read(prefsProvider);
    await prefs.setUserTimezone(tz);
  }

  String _formatMinute(int minute) {
    final h = (minute ~/ 60).toString().padLeft(2, '0');
    final m = (minute % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final repo = ref.watch(repoProvider);
    final hackathons = repo.cachedHackathons;
    final milestonesMap = repo.cachedMilestones;
    final totalMilestones = milestonesMap.values.fold(0, (sum, list) => sum + list.length);
    final totalTeams = repo.allTeams.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Reminder Profile
          const Text(
            'Reminder Cadence Profile',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Standard Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Balanced reminders: 7d, 3d, 1d, 6h, 1h, 15m for Critical'),
                  value: 'standard',
                  groupValue: _profile.id,
                  onChanged: (v) => _setProfile(ReminderProfile.standard),
                ),
                const Divider(height: 1, color: Color(0xFF222234)),
                RadioListTile<String>(
                  title: const Text('Intense Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Frequent alerts: +14d, 12h, 2h, 30m, 5m for high intensity'),
                  value: 'intense',
                  groupValue: _profile.id,
                  onChanged: (v) => _setProfile(ReminderProfile.intense),
                ),
                const Divider(height: 1, color: Color(0xFF222234)),
                RadioListTile<String>(
                  title: const Text('Relaxed Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Minimal alerts: 3d, 1d, 2h for lower distraction'),
                  value: 'relaxed',
                  groupValue: _profile.id,
                  onChanged: (v) => _setProfile(ReminderProfile.relaxed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Quiet Hours
          const Text(
            'Quiet Hours',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Quiet Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Silences Normal and High alerts. Critical alerts always sound.'),
                  value: _quietHours.enabled,
                  onChanged: _toggleQuietHours,
                ),
                if (_quietHours.enabled) ...[
                  const Divider(height: 1, color: Color(0xFF222234)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quiet Period:'),
                        Text(
                          '${_formatMinute(_quietHours.startMinute)} – ${_formatMinute(_quietHours.endMinute)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B85FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Timezone
          const Text(
            'Your Local Timezone',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: ZoneRegistry.all.contains(_userTimezone) ? _userTimezone : 'UTC',
                decoration: const InputDecoration(labelText: 'Display Timezone'),
                items: ZoneRegistry.all.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                onChanged: (v) {
                  if (v != null) _setTimezone(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: Exact Alarm (Android)
          const Text(
            'Android Exact Alarm Status',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                _exactAlarm ? Icons.check_circle : Icons.warning_amber_rounded,
                color: _exactAlarm ? const Color(0xFF00D68F) : const Color(0xFFFFAA00),
              ),
              title: Text(_exactAlarm ? 'Exact Alarms Granted' : 'Exact Alarms Not Granted'),
              subtitle: const Text('Needed for exact second-level alarm delivery on Android 12+'),
              trailing: OutlinedButton(
                onPressed: () async {
                  final prefs = ref.read(prefsProvider);
                  final next = !_exactAlarm;
                  await prefs.setExactAlarmGranted(next);
                  setState(() => _exactAlarm = next);
                },
                child: Text(_exactAlarm ? 'Revoke' : 'Request'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: System & Data Summary
          const Text(
            'Data & Storage',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_off, color: Color(0xFF8888AA)),
                  title: const Text('Sync Engine'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222233),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Local only',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00D68F)),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF222234)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${hackathons.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Text('Hackathons', style: TextStyle(fontSize: 12, color: Color(0xFF777788))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('$totalMilestones', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Text('Milestones', style: TextStyle(fontSize: 12, color: Color(0xFF777788))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('$totalTeams', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Text('Teams', style: TextStyle(fontSize: 12, color: Color(0xFF777788))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
