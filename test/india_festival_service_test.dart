import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/services/india_festival_service.dart';
import 'package:focus_flutter/shared/services/lunar_calendar_service.dart';

void main() {
  test('Diwali 2026 is Nov 8 (IST civil date)', () {
    final lunar = LunarCalendarService();
    final service = IndiaFestivalService(lunar);

    // Diwali (Deepavali) is typically in late Oct / early Nov.
    // This assertion guards against the off-by-one we saw vs India online calendars.
    final oct = service.forMonth(DateTime(2026, 10, 1));
    final nov = service.forMonth(DateTime(2026, 11, 1));

    final all = [...oct, ...nov];
    final diwali = all.where((f) => f.title == 'Diwali').toList();

    expect(diwali.length, 1);
    expect(diwali.single.localDay, DateTime(2026, 11, 8));
  });
}
