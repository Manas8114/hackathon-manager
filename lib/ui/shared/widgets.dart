import 'package:flutter/material.dart';
import '../../engine/models.dart';

// ─── Status chip ──────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final HackathonStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      HackathonStatus.upcoming => ('Upcoming', const Color(0xFF6C63FF)),
      HackathonStatus.running => ('Live', const Color(0xFF00D68F)),
      HackathonStatus.done => ('Done', const Color(0xFFFFAA00)),
      HackathonStatus.archived => ('Archived', const Color(0xFF666677)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Team status chip ─────────────────────────────────────────────────────────

class TeamStatusChip extends StatelessWidget {
  const TeamStatusChip(this.status, {super.key});
  final TeamStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TeamStatus.looking => ('Looking', const Color(0xFFFFAA00)),
      TeamStatus.applied => ('Applied', const Color(0xFF6C63FF)),
      TeamStatus.invited => ('Invited', const Color(0xFF9C27B0)),
      TeamStatus.confirmed => ('Confirmed', const Color(0xFF00D68F)),
      TeamStatus.registered => ('Registered', const Color(0xFF2196F3)),
      TeamStatus.solo => ('Solo', const Color(0xFF00BCD4)),
      TeamStatus.left => ('Left', const Color(0xFFFF6B6B)),
      TeamStatus.disbanded => ('Disbanded', const Color(0xFF9E9E9E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Mode chip ────────────────────────────────────────────────────────────────

class ModeChip extends StatelessWidget {
  const ModeChip(this.mode, {super.key});
  final HackathonMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (mode) {
      HackathonMode.online => ('Online', Icons.wifi_rounded),
      HackathonMode.inPerson => ('In-Person', Icons.location_on_rounded),
      HackathonMode.hybrid => ('Hybrid', Icons.swap_horiz_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF8888AA)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA)),
        ),
      ],
    );
  }
}

// ─── Critical badge ───────────────────────────────────────────────────────────

class CriticalBadge extends StatelessWidget {
  const CriticalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.5), width: 1),
      ),
      child: const Text(
        '⚠ Critical',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFF6B6B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Verified badge ───────────────────────────────────────────────────────────

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 14, color: Color(0xFF00D68F)),
        SizedBox(width: 3),
        Text(
          'Verified',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00D68F),
          ),
        ),
      ],
    );
  }
}

// ─── Priority chip ────────────────────────────────────────────────────────────

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      Priority.critical => ('Critical', const Color(0xFFFF6B6B)),
      Priority.high => ('High', const Color(0xFFFFAA00)),
      Priority.normal => ('Normal', const Color(0xFF6C63FF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6666AA),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Countdown badge ──────────────────────────────────────────────────────────

class CountdownBadge extends StatelessWidget {
  const CountdownBadge(this.deadline, {super.key});
  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final diff = deadline.difference(now);

    String label;
    Color color;
    if (diff.isNegative) {
      label = 'Passed';
      color = const Color(0xFF666677);
    } else if (diff.inHours < 1) {
      label = '${diff.inMinutes}m left';
      color = const Color(0xFFFF6B6B);
    } else if (diff.inHours < 24) {
      label = '${diff.inHours}h left';
      color = const Color(0xFFFFAA00);
    } else {
      label = '${diff.inDays}d left';
      color = const Color(0xFF6C63FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Empty-state widget ───────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF333355)),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888899),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF555566),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
