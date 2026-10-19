import 'package:hackathon_manager/engine/timezone_util.dart';
void main() {
  // 2026-03-08 is the 2nd Sunday of March 2026
  // March 1 2026 is a Sunday, so 2nd Sunday = March 8. Good.
  // Let's check: what does displayWallClock say at 07:00 UTC?
  print(TimezoneUtil.displayWallClock(DateTime.utc(2026, 3, 8, 7, 0), 'America/New_York'));
  print(TimezoneUtil.offsetMinutes(DateTime.utc(2026, 3, 8, 7, 0), 'America/New_York'));
}
