import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';

class MilestoneEditor extends ConsumerStatefulWidget {
  const MilestoneEditor({
    super.key,
    required this.hackathonId,
    this.initial,
  });

  final int hackathonId;
  final Milestone? initial;

  @override
  ConsumerState<MilestoneEditor> createState() => _MilestoneEditorState();
}

class _MilestoneEditorState extends ConsumerState<MilestoneEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _reasonController;
  late TextEditingController _sourceUrlController;
  late MilestoneLabel _label;
  late String _timezone;
  late bool _isCritical;
  late bool _verified;
  late DateTime _endsAtUtc;
  DateTime? _startsAtUtc;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    final now = DateTime.now().toUtc();
    _titleController = TextEditingController(text: m?.title ?? '');
    _reasonController = TextEditingController(text: m?.criticalReason ?? '');
    _sourceUrlController = TextEditingController(text: m?.sourceUrl ?? '');
    _label = m?.label ?? MilestoneLabel.finalSubmission;
    _timezone = m?.timezone ?? 'UTC';
    _isCritical = m?.isCritical ?? true;
    _verified = m?.verified ?? false;
    _endsAtUtc = m?.endsAtUtc ?? now.add(const Duration(days: 3));
    _startsAtUtc = m?.startsAtUtc;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reasonController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repoProvider);
    final scheduler = ref.read(schedulerProvider);
    final now = DateTime.now().toUtc();

    final m = Milestone(
      id: widget.initial?.id ?? -1,
      hackathonId: widget.hackathonId,
      label: _label,
      title: _titleController.text.trim(),
      startsAtUtc: _startsAtUtc,
      endsAtUtc: _endsAtUtc,
      timezone: _timezone,
      isCritical: _isCritical,
      criticalReason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
      sourceUrl: _sourceUrlController.text.trim().isEmpty
          ? null
          : _sourceUrlController.text.trim(),
      verified: _verified,
      createdAt: widget.initial?.createdAt ?? now,
      modifiedAt: now,
    );

    final saved = await repo.saveMilestone(m);
    await scheduler.replanForMilestone(saved.id);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Milestone' : 'Add Milestone'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Milestone Title',
                hintText: 'e.g. Final Submission',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MilestoneLabel>(
              value: _label,
              decoration: const InputDecoration(labelText: 'Milestone Label'),
              items: MilestoneLabel.values.map((l) {
                return DropdownMenuItem(
                  value: l,
                  child: Text(l.displayName),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _label = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: ZoneRegistry.all.contains(_timezone) ? _timezone : 'UTC',
              decoration: const InputDecoration(labelText: 'Timezone'),
              items: ZoneRegistry.all.map((z) {
                return DropdownMenuItem(value: z, child: Text(z));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _timezone = v);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: const Color(0xFF161622),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Deadline (Ends At)'),
              subtitle: Text(
                TimezoneUtil.displayWallClock(_endsAtUtc, _timezone, style: 'full'),
                style: const TextStyle(color: Color(0xFF8B85FF), fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: _pickEndsAt,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              tileColor: const Color(0xFF161622),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Critical Deadline'),
              subtitle: const Text('Hard cutoff with high-cadence alerts'),
              value: _isCritical,
              activeColor: const Color(0xFFFF5252),
              onChanged: (v) => setState(() => _isCritical = v),
            ),
            if (_isCritical) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Critical Reason',
                  hintText: 'e.g. Hard submission cutoff — no extensions',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceUrlController,
              decoration: const InputDecoration(
                labelText: 'Source URL',
                hintText: 'https://hackathon.org/rules',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              tileColor: const Color(0xFF161622),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Verified by Organizer Link'),
              subtitle: const Text('Verified deadlines do not show unverified warnings'),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
          ],
        ),
      ),
    );
  }
}
