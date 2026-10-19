import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../providers/app_providers.dart';

class TeamEditor extends ConsumerStatefulWidget {
  const TeamEditor({
    super.key,
    required this.hackathonId,
    this.initial,
  });

  final int hackathonId;
  final Team? initial;

  @override
  ConsumerState<TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends ConsumerState<TeamEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ideaController;
  late TextEditingController _techStackController;
  late TextEditingController _repoController;
  late TextEditingController _chatController;
  late TextEditingController _notesController;
  late TextEditingController _maxSizeController;
  late TeamStatus _status;

  final List<TeamMember> _members = [];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _nameController = TextEditingController(text: t?.name ?? '');
    _ideaController = TextEditingController(text: t?.ideaTitle ?? '');
    _techStackController = TextEditingController(text: t?.techStackText ?? '');
    _repoController = TextEditingController(text: t?.repoUrl ?? '');
    _chatController = TextEditingController(text: t?.chatUrl ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _maxSizeController = TextEditingController(text: t?.maxSize?.toString() ?? '4');
    _status = t?.status ?? TeamStatus.looking;

    if (t != null) {
      final repo = ref.read(repoProvider);
      _members.addAll(repo.membersFor(t.id));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ideaController.dispose();
    _techStackController.dispose();
    _repoController.dispose();
    _chatController.dispose();
    _notesController.dispose();
    _maxSizeController.dispose();
    super.dispose();
  }

  void _addMember() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    bool isLead = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF181824),
          title: const Text('Add Member', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role (e.g. Lead, Dev)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact (Email, Discord)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Team Lead', style: TextStyle(fontSize: 14)),
                value: isLead,
                onChanged: (v) => setDlgState(() => isLead = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _members.add(TeamMember(
                    id: -1,
                    teamId: widget.initial?.id ?? -1,
                    name: nameCtrl.text.trim(),
                    role: roleCtrl.text.trim().isEmpty ? 'Member' : roleCtrl.text.trim(),
                    contact: contactCtrl.text.trim(),
                    isLead: isLead,
                  ));
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repoProvider);

    // FR-15: Check if another confirmed team exists
    if (_status == TeamStatus.confirmed) {
      final existingTeams = repo.teamsFor(widget.hackathonId);
      final hasAnotherConfirmed = existingTeams.any(
        (t) => t.id != (widget.initial?.id ?? -1) && t.status == TeamStatus.confirmed,
      );

      if (hasAnotherConfirmed) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text('Multiple Confirmed Teams Warning', style: TextStyle(color: Color(0xFFFFAA00))),
            content: const Text(
              'Another confirmed team already exists for this hackathon. '
              'Are you sure you want to confirm a second team?',
              style: TextStyle(color: Color(0xFFDDDDDD)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAA00),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Understand, set anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    // FR-16: Check max size
    final max = int.tryParse(_maxSizeController.text.trim());
    if (max != null && _members.length > max) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Roster Limit Warning', style: TextStyle(color: Color(0xFFFFAA00))),
          content: Text(
            'Team has ${_members.length} members which exceeds the limit of $max. '
            'Save anyway?',
            style: const TextStyle(color: Color(0xFFDDDDDD)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Understand, set anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final now = DateTime.now().toUtc();
    final team = Team(
      id: widget.initial?.id ?? -1,
      hackathonId: widget.hackathonId,
      name: _nameController.text.trim(),
      status: _status,
      ideaTitle: _ideaController.text.trim(),
      techStack: _techStackController.text.trim(),
      repoUrl: _repoController.text.trim(),
      chatUrl: _chatController.text.trim(),
      notes: _notesController.text.trim(),
      maxSize: max,
      createdAt: widget.initial?.createdAt ?? now,
      modifiedAt: now,
    );

    final savedTeam = await repo.saveTeam(team);
    if (_members.isNotEmpty) {
      await repo.saveTeamMembers(savedTeam.id, _members);
    }

    if (mounted) Navigator.of(context).pop(savedTeam);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Create Team' : 'Edit Team'),
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
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TeamStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Team Status'),
              items: TeamStatus.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(s.label));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ideaController,
              decoration: const InputDecoration(labelText: 'Project Idea / Title'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _techStackController,
              decoration: const InputDecoration(
                labelText: 'Tech Stack (comma-separated)',
                hintText: 'Flutter, Python, Fastapi',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _repoController,
                    decoration: const InputDecoration(labelText: 'Repo URL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _chatController,
                    decoration: const InputDecoration(labelText: 'Chat URL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max Team Size'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes / Prep Checklist'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team Members (${_members.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Member'),
                  onPressed: _addMember,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._members.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              return Card(
                color: const Color(0xFF161622),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: m.isLead ? const Color(0xFF6C63FF) : const Color(0xFF28283C),
                    child: Icon(
                      m.isLead ? Icons.star : Icons.person,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m.role} • ${m.contact}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => setState(() => _members.removeAt(idx)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
