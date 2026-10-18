import 'package:test/test.dart';
import 'package:hackathon_manager/engine/timezone_util.dart';

void main() {
  group('ZoneRegistry', () {
    test('contains the zones the seed data and UI need', () {
      for (final z in [
        'UTC',
        'America/New_York',
        'America/Los_Angeles',
        'Europe/London',
        'Europe/Berlin',
        'Asia/Kolkata',
        'Asia/Singapore',
        'Asia/Tokyo',
        'Australia/Sydney',
      ]) {
        expect(ZoneRegistry().contains(z), isTrue, reason: 'missing $z');
      }
    });

    test('unknown zones are rejected', () {
      expect(TimezoneUtil.isValidZone('Mars/Phobos'), isFalse);
      expect(TimezoneUtil.isValidZone(''), isFalse);
      expect(TimezoneUtil.isValidZone('America/NewYork'), isFalse);
    });
  });

  group('offsetMinutes', () {
    test('UTC is zero year round', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 6, 1), 'UTC'), 0);
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 12, 31), 'UTC'), 0);
    });

    test('New York is EDT in summer, EST in winter', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 7, 1), 'America/New_York'), -240);
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 1, 15), 'America/New_York'), -300);
    });

    test('Tokyo is fixed at UTC+9', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 1, 1), 'Asia/Tokyo'), 540);
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 7, 1), 'Asia/Tokyo'), 540);
    });

    test('Kolkata is UTC+5:30', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 7, 1), 'Asia/Kolkata'), 330);
    });

    test('Berlin is UTC+2 in summer, UTC+1 in winter', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 7, 1), 'Europe/Berlin'), 120);
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 1, 15), 'Europe/Berlin'), 60);
    });
  });

  group('displayWallClock', () {
    test('renders an instant in the target zone', () {
      // 2026-10-18T00:00:00Z is 2026-10-17 20:00 in America/New_York (EDT).
      final instant = DateTime.utc(2026, 10, 18, 0, 0, 0);
      final wall = TimezoneUtil.displayWallClock(instant, 'America/New_York');
      expect(wall, contains('20:00'));
      expect(wall, contains('10/17'));
    });

    test('renders the same instant differently across zones', () {
      final instant = DateTime.utc(2026, 10, 18, 0, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'Asia/Tokyo'), contains('09:00'));
      expect(TimezoneUtil.displayWallClock(instant, 'Asia/Tokyo'), contains('10/18'));
    });

    test('applies DST correctly at the US spring-forward boundary', () {
      // 2026-03-08: US spring forward. 07:00Z is 03:00 EDT.
      final instant = DateTime.utc(2026, 3, 8, 7, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'America/New_York'), contains('03:00'));
      // Before the switch: 06:00Z is 01:00 EST.
      final instant2 = DateTime.utc(2026, 3, 8, 6, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant2, 'America/New_York'), contains('01:00'));
    });

    test('applies DST correctly at the US fall-back boundary', () {
      // 2026-11-01: US fall back. 05:00Z is 01:00 EST.
      final instant = DateTime.utc(2026, 11, 1, 5, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'America/New_York'), contains('01:00'));
      // Before the switch: 04:00Z is 00:00 EDT.
      final instant2 = DateTime.utc(2026, 11, 1, 4, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant2, 'America/New_York'), contains('00:00'));
    });

    test('applies DST correctly at the EU boundary', () {
      // 2026-03-29: EU spring forward at 01:00 UTC (last Sunday of March).
      // After the switch, Berlin is CEST (UTC+2): 02:00Z → 04:00 local.
      final instant = DateTime.utc(2026, 3, 29, 2, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'Europe/Berlin'),
          contains('04:00'));
      // Before the switch (00:30Z), Berlin is CET (UTC+1): 00:30Z → 01:30 local.
      final instant2 = DateTime.utc(2026, 3, 29, 0, 30, 0);
      expect(TimezoneUtil.displayWallClock(instant2, 'Europe/Berlin'),
          contains('01:30'));
      // At exactly 01:00Z the switch happens → CEST applies: 01:00Z → 03:00 local.
      final instant3 = DateTime.utc(2026, 3, 29, 1, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant3, 'Europe/Berlin'),
          contains('03:00'));
    });

    test('Sydney DST: AEDT in October, AEST in April', () {
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 10, 15), 'Australia/Sydney'), 660);
      expect(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 4, 15), 'Australia/Sydney'), 600);
    });

    test('UTC renders unchanged', () {
      final instant = DateTime.utc(2026, 10, 18, 9, 30, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'UTC'), contains('09:30'));
    });

    test('full style includes date and time', () {
      final wall = TimezoneUtil.displayWallClock(DateTime.utc(2026, 10, 18, 0, 0, 0),
          'America/New_York', style: 'full');
      expect(wall, contains('20:00'));
      expect(wall, contains('2026'));
    });
  });

  group('zoneAbbr', () {
    test('formats the offset as UTC±H:MM', () {
      expect(TimezoneUtil.zoneAbbr('UTC', DateTime.utc(2026, 1, 1)), 'UTC');
      expect(TimezoneUtil.zoneAbbr('Asia/Tokyo', DateTime.utc(2026, 1, 1)),
          'UTC+09:00');
      expect(TimezoneUtil.zoneAbbr('Asia/Kolkata', DateTime.utc(2026, 1, 1)),
          'UTC+05:30');
      expect(TimezoneUtil.zoneAbbr('America/New_York', DateTime.utc(2026, 1, 1)),
          'UTC-05:00');
    });
  });

  group('formatInstant', () {
    test('formats durations as the PRD cadence labels', () {
      expect(TimezoneUtil.formatInstant(const Duration(days: 7)), '7 d');
      expect(TimezoneUtil.formatInstant(const Duration(hours: 6)), '6 h');
      expect(TimezoneUtil.formatInstant(const Duration(minutes: 15)), '15 m');
      expect(TimezoneUtil.formatInstant(const Duration(days: 1, hours: 1)), '1 d 1 h');
      expect(TimezoneUtil.formatInstant(Duration.zero), 'now');
    });
  });
}
