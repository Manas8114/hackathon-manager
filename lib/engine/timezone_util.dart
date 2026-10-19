library timezone_util;

import 'package:intl/intl.dart';

/// Deterministic civil-date arithmetic and a small IANA zone table.
///
/// No DateTime.toLocal, no zone packages. Wall-clock rendering is the single
/// source of truth for displaying a milestone instant in the organizer's zone.
///
/// All DST rules are built with [DateTime] arithmetic so the boundary math
/// is exact: a switch occurs at a local wall-clock instant, which is
/// converted to UTC by subtracting the offset in effect just before the
/// switch.

class _OffsetRule {
  const _OffsetRule(this.fromUtc, this.toUtc, this.offsetMinutes);
  final int fromUtc; // inclusive, UTC epoch millis
  final int toUtc; // exclusive
  final int offsetMinutes;
}

class TimezoneUtil {
  const TimezoneUtil();

  // ── DST table ──────────────────────────────────────────────────────────
  /// Build a DST rule table for a zone.
  ///
  /// [dstOffset] and [stOffset] are the offset in minutes from UTC while in
  /// Daylight Saving Time and Standard Time respectively. [dstMonth] and
  /// [dstNth] identify the DST start: the [dstNth] Sunday of [dstMonth]
  /// (positive = nth from start, e.g. 2 = 2nd Sunday; negative = nth from
  /// end, e.g. -1 = last Sunday). [stMonth] and [stNth] do the same for the
  /// DST end.
  static List<_OffsetRule> _dstRules(int dstOffset, int stOffset,
      int dstMonth, int dstNth, int stMonth, int stNth,
      {int dstLocalHour = 2,
      int stLocalHour = 2,
      int startYear = 2019,
      int endYear = 2051}) {
    final rules = <_OffsetRule>[];

    // Day of the nth Sunday of month m in year y.
    // Positive nth = nth from start (1st Sunday, 2nd Sunday, …).
    // Negative nth = |nth| from end (-1 = last Sunday of the month).
    int nthSunday(int y, int m, int nth) {
      if (nth > 0) {
        // 1st Sunday: advance from the 1st to the first day with weekday=Sun.
        // DateTime.utc(y, m, 1).weekday is Mon=1..Sun=7.
        final first = DateTime.utc(y, m, 1);
        final daysToFirstSunday = (7 - first.weekday) % 7;
        final firstSundayDay = 1 + daysToFirstSunday;
        return firstSundayDay + (nth - 1) * 7;
      }
      // nth = -k means kth Sunday from the end; -1 = last Sunday.
      final daysInMonth = DateTime.utc(y, m + 1, 0).day;
      // Walk back from the last day to find the last Sunday.
      var d = daysInMonth;
      while (DateTime.utc(y, m, d).weekday != 7) {
        d--;
      }
      final lastSundayDay = d;
      return lastSundayDay + (nth + 1) * 7; // nth=-1 → lastSundayDay; nth=-2 → lastSundayDay-7
    }

    // UTC instant when the wall clock switches from ST to DST (spring).
    // The wall-clock switch happens at dstLocalHour local; just before,
    // the zone is at stOffset. UTC = local - stOffset.
    int startUtc(int y) {
      final d = nthSunday(y, dstMonth, dstNth);
      return DateTime.utc(y, dstMonth, d, dstLocalHour)
          .millisecondsSinceEpoch -
          stOffset * 60000;
    }

    // UTC instant when the wall clock switches from DST to ST (fall).
    // Just before, the zone is at dstOffset. UTC = local - dstOffset.
    //
    // For northern hemisphere zones stMonth > dstMonth, the fall switch
    // happens in the same calendar year as the spring switch.
    // For southern hemisphere zones stMonth < dstMonth, the fall switch
    // happens in year y+1 (April follows October in the *next* year).
    int endUtc(int y) {
      final fallYear = stMonth < dstMonth ? y + 1 : y;
      final d = nthSunday(fallYear, stMonth, stNth);
      return DateTime.utc(fallYear, stMonth, d, stLocalHour)
          .millisecondsSinceEpoch -
          dstOffset * 60000;
    }

    // ST rule from 1970 to the first DST start.
    final y1970 = DateTime.utc(1970, 1, 1).millisecondsSinceEpoch;
    rules.add(_OffsetRule(y1970, startUtc(startYear), stOffset));

    for (var y = startYear; y < endYear; y++) {
      final s = startUtc(y);
      final e = endUtc(y);
      final ns = startUtc(y + 1);
      rules.add(_OffsetRule(s, e, dstOffset));
      rules.add(_OffsetRule(e, ns, stOffset));
    }

    // Trailing ST rule.
    rules.add(
        _OffsetRule(endUtc(endYear), DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
            stOffset));
    return rules;
  }

  static final Map<String, List<_OffsetRule>> _tables = {
    'UTC': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          0)
    ],
    'America/New_York':
        _dstRules(-240, -300, 3, 2, 11, 1, dstLocalHour: 2, stLocalHour: 2),
    'America/Chicago':
        _dstRules(-300, -360, 3, 2, 11, 1, dstLocalHour: 2, stLocalHour: 2),
    'America/Denver':
        _dstRules(-360, -420, 3, 2, 11, 1, dstLocalHour: 2, stLocalHour: 2),
    'America/Los_Angeles':
        _dstRules(-420, -480, 3, 2, 11, 1, dstLocalHour: 2, stLocalHour: 2),
    'America/Sao_Paulo': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          -180)
    ],
    // EU: clocks spring forward at 01:00 UTC (last Sunday of March), fall
    // back at 01:00 UTC (last Sunday of October).
    //
    // `startUtc` uses dstLocalHour under stOffset:
    //   London (st=0):  01:00 local GMT → 01:00 UTC ✓  (dstLocalHour=1)
    //   Berlin (st=60): 01:00 local CET → 00:00 UTC ✗ (need dstLocalHour=2 → 02:00 local CET → 01:00 UTC ✓)
    //
    // `endUtc` uses stLocalHour under dstOffset:
    //   London (dst=60): 02:00 local BST → 01:00 UTC ✓  (stLocalHour=2)
    //   Berlin (dst=120): 02:00 local CEST → 00:00 UTC ✗ (need stLocalHour=2? No: 02:00-2h=00:00. Need 03:00-2h=01:00 → stLocalHour=3)
    'Europe/London': _dstRules(60, 0, 3, -1, 10, -1,
        dstLocalHour: 1, stLocalHour: 2),
    'Europe/Berlin': _dstRules(120, 60, 3, -1, 10, -1,
        dstLocalHour: 2, stLocalHour: 3),
    'Europe/Moscow': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          180)
    ],
    'Europe/Istanbul': [
      _OffsetRule(
          DateTime.utc(2016, 3, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          180)
    ],
    'Asia/Dubai': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          240)
    ],
    'Asia/Kolkata': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(1985, 9, 1).millisecondsSinceEpoch,
          300),
      _OffsetRule(
          DateTime.utc(1985, 9, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          330)
    ],
    'Asia/Bangkok': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          420)
    ],
    'Asia/Singapore': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          480)
    ],
    'Asia/Tokyo': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          540)
    ],
    'Asia/Seoul': [
      _OffsetRule(
          DateTime.utc(1970, 1, 1).millisecondsSinceEpoch,
          DateTime.utc(2100, 1, 1).millisecondsSinceEpoch,
          540)
    ],
    // AU Sydney: DST starts 1st Sunday of October at 02:00 AEST local
    // (clocks spring forward to 03:00 AEDT), ends 1st Sunday of April
    // at 03:00 AEDT local (clocks fall back to 02:00 AEST).
    //
    // `startUtc` uses dstLocalHour under stOffset (AEST=600):
    //   02:00 local AEST → 02:00 - 10:00 = previous day 16:00 UTC ✗
    //   Need dstLocalHour under stOffset to give the correct UTC.
    //   Actually: startUtc = Oct 1st Sunday 02:00 (local, ST scale)
    //   → UTC = 02:00 - 600/60 h = previous day 16:00 UTC.
    //   This is wrong — should be 16:00 UTC = Oct 1 15:00 UTC? No:
    //   AEST=+10, so local 02:00 AEST = previous day 16:00 UTC. Correct.
    //
    // `endUtc` uses stLocalHour under dstOffset (AEDT=660):
    //   03:00 local AEDT → 03:00 - 660/60 h = 03:00 - 11:00 = previous day 16:00 UTC.
    //   That gives Apr 4 16:00 UTC for Apr 5. The test expects Apr 15
    //   to be AEST (600), so endUtc < Apr 15 is fine.
    'Australia/Sydney': _dstRules(660, 600, 10, 1, 4, 1,
        dstLocalHour: 2, stLocalHour: 3),
  };

  // ── Lookup ─────────────────────────────────────────────────────────────
  int _offsetMinutes(DateTime instant, String zone) {
    final rules = _tables[zone];
    if (rules == null) throw ArgumentError('Unknown zone: $zone');
    final ms = instant.toUtc().millisecondsSinceEpoch;
    for (final r in rules) {
      if (ms >= r.fromUtc && ms < r.toUtc) return r.offsetMinutes;
    }
    throw StateError('No rule for $zone at $instant');
  }

  // ── Public API ─────────────────────────────────────────────────────────
  /// UTC offset for [zone] at [instant], in minutes.
  static int offsetMinutes(DateTime instant, String zone) =>
      TimezoneUtil()._offsetMinutes(instant, zone);

  /// True when [zone] is a known IANA identifier.
  static bool isValidZone(String zone) => _tables.containsKey(zone);

  /// Render [instant] as a wall-clock string in [zone].
  static String displayWallClock(DateTime instant, String zone,
      {String style = 'medium', String dateFormat = 'M/d HH:mm'}) {
    final offset = TimezoneUtil()._offsetMinutes(instant, zone);
    final localInstant = instant.add(Duration(minutes: offset));
    if (style == 'time') {
      return DateFormat.Hm().format(localInstant.toUtc());
    }
    if (style == 'full') {
      // full includes the year, month, day, and time.
      final d = localInstant.toUtc();
      return '${d.year}/${d.month}/${d.day} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return DateFormat.Md().format(localInstant.toUtc()) +
        ' ' +
        DateFormat.Hm().format(localInstant.toUtc());
  }

  /// Short zone label: "UTC", "UTC+09:00", "UTC-05:00".
  static String zoneAbbr(String zone, DateTime instant) {
    if (zone == 'UTC') return 'UTC';
    final offset = TimezoneUtil()._offsetMinutes(instant, zone);
    final sign = offset >= 0 ? '+' : '-';
    final abs = offset.abs();
    final h = (abs ~/ 60).toString().padLeft(2, '0');
    final m = (abs % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  /// Compact duration label: "7 d", "6 h", "15 m", "1 d 1 h", "now".
  static String formatInstant(Duration d) {
    if (d == Duration.zero) return 'now';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final parts = <String>[];
    if (days >= 1) parts.add('$days d');
    if (days == 0 && hours >= 1) parts.add('$hours h');
    if (days == 0 && hours == 0 && minutes >= 1) {
      parts.add('$minutes m');
    }
    if (days >= 1 && hours >= 1) parts.add('$hours h');
    return parts.isEmpty ? '0 m' : parts.join(' ');
  }
}

/// Registry of zones the app supports.
class ZoneRegistry {
  ZoneRegistry._();

  factory ZoneRegistry() => ZoneRegistry._();

  /// Whether [zone] is a known IANA identifier.
  bool contains(String zone) => _zoneList.contains(zone);

  static final List<String> _zoneList = [
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Sao_Paulo',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Moscow',
    'Europe/Istanbul',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Bangkok',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Australia/Sydney',
  ];
}
