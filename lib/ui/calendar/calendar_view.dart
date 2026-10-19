import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/priority.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now().toUtc();
    _currentMonth = DateTime.utc(d.year, d.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime.utc(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime.utc(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  Priority _priorityFor(Milestone m) {
    if (m.isCritical) return Priority.critical;
    return PriorityClassifier.classify(m.label, m.title).$1;
  }

  Color _colorForPriority(Priority p) {
    return switch (p) {
      Priority.critical => const Color(0xFFFF5252),
      Priority.high => const Color(0xFFFFAA00),
      Priority.normal => const Color(0xFF6C63FF),
    };
  }

  void _showDayDetails(
    BuildContext context,
    DateTime day,
    List<Milestone> milestones,
    Map<int, Hackathon> hackathonsMap,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (milestones.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No deadlines on this day', style: TextStyle(color: Color(0xFF888899))),
                )
              else
                ...milestones.map((m) {
                  final h = hackathonsMap[m.hackathonId];
                  final prio = _priorityFor(m);
                  final color = _colorForPriority(prio);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if (h != null)
                                Text(
                                  h.name,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF9999AA)),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          TimezoneUtil.displayWallClock(m.endsAtUtc, m.timezone, style: 'time'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: StreamBuilder<List<Hackathon>>(
        stream: repo.watchHackathons(),
        builder: (context, hSnapshot) {
          final hackathons = hSnapshot.data ?? [];
          final hackathonsMap = {for (final h in hackathons) h.id: h};

          return StreamBuilder<Map<int, List<Milestone>>>(
            stream: repo.watchMilestonesGrouped(),
            builder: (context, mSnapshot) {
              final grouped = mSnapshot.data ?? {};
              final allMilestones = grouped.values.expand((list) => list).toList();

              // Days in current month
              final firstDayOfMonth = DateTime.utc(_currentMonth.year, _currentMonth.month, 1);
              final daysInMonth = DateTime.utc(_currentMonth.year, _currentMonth.month + 1, 0).day;
              final startWeekday = firstDayOfMonth.weekday % 7; // Sunday=0, Monday=1...

              final monthName = switch (_currentMonth.month) {
                1 => 'January',
                2 => 'February',
                3 => 'March',
                4 => 'April',
                5 => 'May',
                6 => 'June',
                7 => 'July',
                8 => 'August',
                9 => 'September',
                10 => 'October',
                11 => 'November',
                12 => 'December',
                _ => '',
              };

              return Column(
                children: [
                  // Month navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$monthName ${_currentMonth.year}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _prevMonth,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Weekday headers
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Sun', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Mon', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Tue', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Wed', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Thu', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Fri', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Sat', style: TextStyle(color: Color(0xFF777788), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Days grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.9,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: 42, // 6 weeks * 7 days
                      itemBuilder: (context, index) {
                        final dayNumber = index - startWeekday + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox.shrink();
                        }

                        final currentDay = DateTime.utc(_currentMonth.year, _currentMonth.month, dayNumber);
                        final dayMilestones = allMilestones.where((m) {
                          return m.endsAtUtc.year == currentDay.year &&
                              m.endsAtUtc.month == currentDay.month &&
                              m.endsAtUtc.day == currentDay.day;
                        }).toList();

                        final now = DateTime.now().toUtc();
                        final isToday = now.year == currentDay.year &&
                            now.month == currentDay.month &&
                            now.day == currentDay.day;

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showDayDetails(context, currentDay, dayMilestones, hackathonsMap),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                                  : const Color(0xFF14141E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isToday ? const Color(0xFF6C63FF) : const Color(0xFF222230),
                                width: isToday ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? const Color(0xFF8B85FF) : Colors.white,
                                  ),
                                ),
                                // Dots for milestones
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dayMilestones.take(3).map((m) {
                                    final p = _priorityFor(m);
                                    final c = _colorForPriority(p);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Month milestone summary
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upcoming This Month',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
                        ),
                        const SizedBox(height: 8),
                        ...allMilestones
                            .where((m) =>
                                m.endsAtUtc.year == _currentMonth.year &&
                                m.endsAtUtc.month == _currentMonth.month)
                            .take(4)
                            .map((m) {
                          final h = hackathonsMap[m.hackathonId];
                          final prio = _priorityFor(m);
                          final color = _colorForPriority(prio);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${h?.name ?? 'Hackathon'}: ${m.title}',
                                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  TimezoneUtil.displayWallClock(m.endsAtUtc, m.timezone, style: 'compact'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
