import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/services/online_festival_calendar_service.dart';

void main() {
  test('parses SUMMARY with parameters + VALUE=DATE DTSTART', () {
    const ics = '''
BEGIN:VCALENDAR
X-WR-CALNAME:My Holidays
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260215
DTEND;VALUE=DATE:20260216
SUMMARY;LANGUAGE=en:Maha Shivaratri
END:VEVENT
END:VCALENDAR
''';

    final data = OnlineFestivalCalendarService.instance.parseIcsForYear(ics, year: 2026);
    expect(data.calendarName, 'My Holidays');
    expect(data.events.length, 1);
    expect(data.events.first.title, 'Maha Shivaratri');
    expect(data.events.first.localDay, DateTime(2026, 2, 15));
    expect(data.events.first.subtitle, 'Online • My Holidays');
  });

  test('converts UTC DTSTART date-time into IST local date', () {
    // 2026-02-14 18:30Z is 2026-02-15 00:00 in IST.
    const ics = '''
BEGIN:VCALENDAR
X-WR-CALNAME:UTC Calendar
BEGIN:VEVENT
DTSTART:20260214T183000Z
SUMMARY:Midnight IST Holiday
END:VEVENT
END:VCALENDAR
''';

    final data = OnlineFestivalCalendarService.instance.parseIcsForYear(ics, year: 2026);
    expect(data.events.length, 1);
    expect(data.events.first.localDay, DateTime(2026, 2, 15));
  });
}
