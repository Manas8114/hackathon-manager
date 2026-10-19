import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';

class AddHackathonSheet extends ConsumerStatefulWidget {
  const AddHackathonSheet({super.key});

  @override
  ConsumerState<AddHackathonSheet> createState() => _AddHackathonSheetState();
}

class _AddHackathonSheetState extends ConsumerState<AddHackathonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _organizerController = TextEditingController();
  final _urlController = TextEditingController();
  final _locationController = TextEditingController();
  final _milestoneTitleController = TextEditingController(text: 'Final Submission');

  HackathonMode _mode = HackathonMode.online;
  String _timezone = 'America/New_York';
  DateTime _endsAtUtc = DateTime.now().toUtc().add(const Duration(days: 3));
  bool _addMilestone = true;
  bool _isCritical = true;

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    _urlController.dispose();
    _locationController.dispose();
    _milestoneTitleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAtUtc,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _endsAtUtc.hour, minute: _endsAtUtc.minute),
    );
    if (time == null) return;
    setState(() {
      _endsAtUtc = DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repoProvider);
    final scheduler = ref.read(schedulerProvider);
    final now = DateTime.now().toUtc();

    final h = Hackathon(
      id: -1,
      name: _nameController.text.trim(),
      organizer: _organizerController.text.trim().isEmpty
          ? 'Independent'
          : _organizerController.text.trim(),
      url: _urlController.text.trim(),
      mode: _mode,
      location: _locationController.text.trim(),
      organizerTimezone: _timezone,
      status: HackathonStatus.upcoming,
      createdAt: now,
      modifiedAt: now,
    );

    final saved = await repo.saveHackathon(h);

    if (_addMilestone) {
      final m = Milestone(
        id: -1,
        hackathonId: saved.id,
        label: MilestoneLabel.finalSubmission,
        title: _milestoneTitleController.text.trim().isEmpty
            ? 'Final submission'
            : _milestoneTitleController.text.trim(),
        endsAtUtc: _endsAtUtc,
        timezone: _timezone,
        isCritical: _isCritical,
        criticalReason: 'Official closing deadline',
        sourceUrl: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
        verified: true,
        createdAt: now,
        modifiedAt: now,
      );
      final savedMilestone = await repo.saveMilestone(m);
      await scheduler.replanForMilestone(savedMilestone.id);
    }

    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Hackathon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEEEEFF),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hackathon Name *',
                  hintText: 'e.g. TreeHacks 2026',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _organizerController,
                      decoration: const InputDecoration(
                        labelText: 'Organizer',
                        hintText: 'e.g. Stanford University',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<HackathonMode>(
                      value: _mode,
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: HackathonMode.values.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m.label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _mode = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Website / Devpost URL',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ZoneRegistry.all.contains(_timezone) ? _timezone : 'UTC',
                decoration: const InputDecoration(labelText: 'Organizer Timezone'),
                items: ZoneRegistry.all.map((z) {
                  return DropdownMenuItem(value: z, child: Text(z));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _timezone = v);
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF262638)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Initial Milestone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B85FF),
                    ),
                  ),
                  Switch(
                    value: _addMilestone,
                    onChanged: (v) => setState(() => _addMilestone = v),
                  ),
                ],
              ),
              if (_addMilestone) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _milestoneTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone Title',
                    hintText: 'e.g. Final Submission',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: const Text('Deadline', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  subtitle: Text(
                    TimezoneUtil.displayWallClock(_endsAtUtc, _timezone, style: 'full'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: _pickDate,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Save Hackathon',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
