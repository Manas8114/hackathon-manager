import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/quiet_hours.dart';

// toLocal for the test: UTC is the user's zone, so local == UTC.
DateTime _utcToLocal(DateTime utc) => utc;

const _nights = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60, enabled: true);

void main() {
  group('basic suppression', () {
    test('normal reminder inside quiet hours is suppressed to the next permitted minute', () {
      final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 4, 0, 0), Priority.normal,
          _nights, _utcToLocal);
      expect(d.decision, SuppressDecision.suppress);
      expect(d.effectiveAtUtc, DateTime.utc(2026, 10, 18, 7, 0, 0));
    });

    test('high priority is also suppressed during quiet hours', () {
      final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 23, 0, 0), Priority.high,
          _nights, _utcToLocal);
      expect(d.decision, SuppressDecision.suppress);
    });

    test('critical fires regardless of quiet hours', () {
      final at = DateTime.utc(2026, 10, 18, 23, 0, 0);
      final d = QuietHoursGate.gate(at, Priority.critical, _nights, _utcToLocal);
      expect(d.decision, SuppressDecision.fire);
      expect(d.effectiveAtUtc, at);
    });

    test('normal fires outside quiet hours', () {
      final at = DateTime.utc(2026, 10, 18, 15, 0, 0);
      final d = QuietHoursGate.gate(at, Priority.normal, _nights, _utcToLocal);
      expect(d.decision, SuppressDecision.fire);
      expect(d.effectiveAtUtc, at);
    });
  });

  group('quiet hours disabled', () {
    test('no quiet hours means everything fires immediately', () {
      final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 4, 0, 0), Priority.normal,
          QuietHours.none, _utcToLocal);
      expect(d.decision, SuppressDecision.fire);
    });

    test('an enabled=false window does not suppress', () {
      const disabled = QuietHours(startMinute: 0, endMinute: 1440, enabled: false);
      final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 12, 0, 0), Priority.normal,
          disabled, _utcToLocal);
      expect(d.decision, SuppressDecision.fire);
    });
  });

  group('window shape', () {
    test('non-wrapping window treats end after start normally', () {
      const midday = QuietHours(startMinute: 12 * 60, endMinute: 14 * 60, enabled: true);
      final inside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 13, 0, 0),
          Priority.normal, midday, _utcToLocal);
      final outside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 15, 0, 0),
          Priority.normal, midday, _utcToLocal);
      final atStart = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 12, 0, 0),
          Priority.normal, midday, _utcToLocal);
      final atEnd = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 14, 0, 0),
          Priority.normal, midday, _utcToLocal);
      expect(inside.decision, SuppressDecision.suppress);
      expect(outside.decision, SuppressDecision.fire);
      // The start minute is inside; the end minute is outside (half-open).
      expect(atStart.decision, SuppressDecision.suppress);
      expect(atEnd.decision, SuppressDecision.fire);
    });

    test('wrapping window correctly spans midnight', () {
      final justInside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 22, 30, 0),
          Priority.normal, _nights, _utcToLocal);
      final afterMidnight = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 3, 0, 0),
          Priority.normal, _nights, _utcToLocal);
      final justAfter = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 7, 5, 0),
          Priority.normal, _nights, _utcToLocal);
      expect(justInside.decision, SuppressDecision.suppress);
      expect(afterMidnight.decision, SuppressDecision.suppress);
      expect(justAfter.decision, SuppressDecision.fire);
    });

    test('a suppressed fire time lands strictly after the original time', () {
      final at = DateTime.utc(2026, 10, 18, 6, 59, 30);
      final d = QuietHoursGate.gate(at, Priority.normal, _nights, _utcToLocal);
      expect(d.decision, SuppressDecision.suppress);
      expect(d.effectiveAtUtc.isAfter(at), isTrue);
    });

    test('wrapsMidnight reports the shape', () {
      expect(_nights.wrapsMidnight, isTrue);
      const midday = QuietHours(startMinute: 8 * 60, endMinute: 10 * 60, enabled: true);
      expect(midday.wrapsMidnight, isFalse);
    });
  });
}
