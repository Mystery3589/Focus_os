import 'package:geoengine/geoengine.dart';

import 'lunar_calendar_service.dart';

class FestivalInstance {
  final DateTime localDay;
  final String title;
  final String subtitle;

  const FestivalInstance({
    required this.localDay,
    required this.title,
    required this.subtitle,
  });
}

/// India-focused, offline, astronomy-backed festival generator.
///
/// IMPORTANT:
/// - This intentionally covers **major pan-India festivals** with pragmatic rules.
/// - Many Hindu festivals are region-specific and/or sunrise-based and require a full Panchang
///   (location, sunrise, lunar month rules, etc.). We avoid AGPL Panchang libraries.
/// - We label these as "Auto" in the subtitle, and users can always add/edit their own events.
class IndiaFestivalService {
  final LunarCalendarService _lunar;

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Sunrise-like boundary hour for assigning a civil day to a lunar tithi/event.
  ///
  /// Many Panchang calendars are effectively sunrise-based. Without location-based
  /// sunrise, we approximate with a fixed local hour.
  final int sunriseBoundaryHour;

  // Cache by YYYYMM.
  final _cache = <int, List<FestivalInstance>>{};
  static const int _maxEntries = 60;

  IndiaFestivalService(this._lunar, {this.sunriseBoundaryHour = 6});

  int _monthKey(DateTime d) => d.year * 100 + d.month;
  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _toIstClock(DateTime dt) => dt.toUtc().add(_istOffset);

  List<FestivalInstance> forMonth(DateTime focusedLocalMonth) {
    final key = _monthKey(focusedLocalMonth);
    final existing = _cache[key];
    if (existing != null) {
      _cache.remove(key);
      _cache[key] = existing;
      return existing;
    }

    final y = focusedLocalMonth.year;
    final m = focusedLocalMonth.month;

    // We generate using windows that can spill to neighbor months.
    final monthStart = DateTime(y, m, 1);
    final monthEnd = DateTime(y, m + 1, 0);

    final out = <FestivalInstance>[];

    // Moon-quarter based festivals (New/Full moon closest to a window).
    out.addAll(
      _festivalByTithiNearMoonQuarter(
        name: 'Diwali',
        subtitle: 'Auto: Amavasya (tithi 30) near New Moon • IST sunset-based',
        quarterIndex: 0, // New Moon anchor
        tithi: 30, // Amavasya
        sampleHourIst: 18, // approximate sunset/pradosh window
        start: DateTime(y, 10, 15),
        end: DateTime(y, 11, 15),
      ),
    );

    out.addAll(
      _festivalByMoonQuarter(
        name: 'Holi',
        subtitle: 'Auto: Purnima window (Mar) • sunrise-based',
        quarterIndex: 2,
        start: DateTime(y, 3, 1),
        end: DateTime(y, 3, 31),
      ),
    );

    out.addAll(
      _festivalByMoonQuarter(
        name: 'Raksha Bandhan',
        subtitle: 'Auto: Purnima window (Aug) • sunrise-based',
        quarterIndex: 2,
        start: DateTime(y, 8, 1),
        end: DateTime(y, 8, 31),
      ),
    );

    out.addAll(
      _festivalByMoonQuarter(
        name: 'Buddha Purnima',
        subtitle: 'Auto: Purnima window (May) • sunrise-based',
        quarterIndex: 2,
        start: DateTime(y, 5, 1),
        end: DateTime(y, 5, 31),
      ),
    );

    // Tithi-window festivals (picked by scanning days).
    out.addAll(
      _festivalByTithi(
        name: 'Maha Shivaratri',
        subtitle: 'Auto: Krishna Chaturdashi window (Feb–Mar) • sunrise-based',
        tithi: 29, // Krishna Chaturdashi
        start: DateTime(y, 2, 10),
        end: DateTime(y, 3, 20),
      ),
    );

    out.addAll(
      _festivalByTithi(
        name: 'Ganesh Chaturthi',
        subtitle: 'Auto: Shukla Chaturthi window (Aug–Sep) • sunrise-based',
        tithi: 4, // Shukla Chaturthi
        start: DateTime(y, 8, 10),
        end: DateTime(y, 9, 30),
      ),
    );

    out.addAll(
      _festivalByTithi(
        name: 'Janmashtami',
        subtitle: 'Auto: Krishna Ashtami window (Aug–Sep) • sunrise-based',
        tithi: 23, // Krishna Ashtami
        start: DateTime(y, 8, 10),
        end: DateTime(y, 9, 30),
      ),
    );

    out.addAll(
      _festivalByTithi(
        name: 'Ram Navami',
        subtitle: 'Auto: Shukla Navami window (Mar–Apr) • sunrise-based',
        tithi: 9, // Shukla Navami
        start: DateTime(y, 3, 15),
        end: DateTime(y, 4, 30),
      ),
    );

    out.addAll(
      _festivalByTithi(
        name: 'Vijayadashami (Dussehra)',
        subtitle: 'Auto: Shukla Dashami window (Sep–Oct) • sunrise-based',
        tithi: 10, // Shukla Dashami
        start: DateTime(y, 9, 15),
        end: DateTime(y, 10, 31),
      ),
    );

    out.addAll(
      _festivalByTithi(
        name: 'Karva Chauth',
        subtitle: 'Auto: Krishna Chaturthi window (Oct) • sunrise-based',
        tithi: 19, // Krishna Chaturthi
        start: DateTime(y, 10, 1),
        end: DateTime(y, 10, 31),
      ),
    );

    // Keep only items that fall inside the month.
    final filtered = out
        .where(
          (f) =>
              !f.localDay.isBefore(_dayStart(monthStart)) &&
              !f.localDay.isAfter(_dayStart(monthEnd)),
        )
        .toList();

    // Stable sort by day.
    filtered.sort((a, b) => a.localDay.compareTo(b.localDay));

    _cache[key] = filtered;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    return filtered;
  }

  List<FestivalInstance> _festivalByMoonQuarter({
    required String name,
    required String subtitle,
    required int quarterIndex,
    required DateTime start,
    required DateTime end,
  }) {
    final startUtc = DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).subtract(const Duration(days: 2));
    final endUtc = DateTime.utc(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).add(const Duration(days: 2));

    final results = <MoonQuarter>[];

    MoonQuarter? mq;
    try {
      mq = MoonQuarter.searchMoonQuarter(startUtc);
    } catch (_) {
      mq = null;
    }

    for (var i = 0; i < 96 && mq != null; i++) {
      final t = mq.time.date;
      if (t.isAfter(endUtc)) break;
      if (!t.isBefore(startUtc)) {
        if (mq.quarterIndex == quarterIndex) results.add(mq);
      }
      try {
        mq = MoonQuarter.nextMoonQuarter(mq);
      } catch (_) {
        mq = null;
      }
    }

    if (results.isEmpty) return const [];

    // Choose the first matching one in the window; in practice there should be one.
    final chosen = results.first;
    final ist = _toIstClock(chosen.time.date);

    // Sunrise-based assignment in IST.
    var day = DateTime(ist.year, ist.month, ist.day);
    if (ist.hour < sunriseBoundaryHour) {
      day = day.subtract(const Duration(days: 1));
    }

    return [FestivalInstance(localDay: day, title: name, subtitle: subtitle)];
  }

  DateTime? _firstMoonQuarterUtcInWindow({
    required int quarterIndex,
    required DateTime start,
    required DateTime end,
  }) {
    final startUtc = DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).subtract(const Duration(days: 2));
    final endUtc = DateTime.utc(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).add(const Duration(days: 2));

    MoonQuarter? mq;
    try {
      mq = MoonQuarter.searchMoonQuarter(startUtc);
    } catch (_) {
      mq = null;
    }

    for (var i = 0; i < 96 && mq != null; i++) {
      final t = mq.time.date;
      if (t.isAfter(endUtc)) break;
      if (!t.isBefore(startUtc) && mq.quarterIndex == quarterIndex) {
        return t;
      }
      try {
        mq = MoonQuarter.nextMoonQuarter(mq);
      } catch (_) {
        mq = null;
      }
    }

    return null;
  }

  /// Finds a tithi-based festival day by sampling at a specific IST clock time
  /// and choosing the match closest (in time) to a moon-quarter anchor.
  ///
  /// This is useful for calendars where the "festival day" convention aligns
  /// better with a tithi prevailing at sunset/pradosh (e.g. Diwali) than with
  /// the exact new-moon moment.
  List<FestivalInstance> _festivalByTithiNearMoonQuarter({
    required String name,
    required String subtitle,
    required int quarterIndex,
    required int tithi,
    required int sampleHourIst,
    required DateTime start,
    required DateTime end,
  }) {
    final anchorUtc = _firstMoonQuarterUtcInWindow(
      quarterIndex: quarterIndex,
      start: start,
      end: end,
    );
    if (anchorUtc == null) {
      // Fallback: pick the first match in the window using the requested sample time.
      return _festivalByTithiAtIstTime(
        name: name,
        subtitle: subtitle,
        tithi: tithi,
        sampleHourIst: sampleHourIst,
        start: start,
        end: end,
      );
    }

    FestivalInstance? best;
    Duration? bestAbsDiff;

    for (
      var d = _dayStart(start);
      !d.isAfter(_dayStart(end));
      d = d.add(const Duration(days: 1))
    ) {
      final sampleUtc = DateTime.utc(
        d.year,
        d.month,
        d.day,
        sampleHourIst,
        0,
        0,
      ).subtract(_istOffset);
      final info = _lunar.forMoment(sampleUtc);
      if (info.tithi != tithi) continue;

      final diff = sampleUtc.difference(anchorUtc);
      final absDiff = diff.isNegative ? -diff : diff;

      if (best == null ||
          absDiff < (bestAbsDiff ?? const Duration(days: 99999))) {
        best = FestivalInstance(localDay: d, title: name, subtitle: subtitle);
        bestAbsDiff = absDiff;
      }
    }

    return best == null ? const [] : [best];
  }

  List<FestivalInstance> _festivalByTithiAtIstTime({
    required String name,
    required String subtitle,
    required int tithi,
    required int sampleHourIst,
    required DateTime start,
    required DateTime end,
  }) {
    for (
      var d = _dayStart(start);
      !d.isAfter(_dayStart(end));
      d = d.add(const Duration(days: 1))
    ) {
      final sampleUtc = DateTime.utc(
        d.year,
        d.month,
        d.day,
        sampleHourIst,
        0,
        0,
      ).subtract(_istOffset);
      final info = _lunar.forMoment(sampleUtc);
      if (info.tithi == tithi) {
        return [FestivalInstance(localDay: d, title: name, subtitle: subtitle)];
      }
    }

    return const [];
  }

  List<FestivalInstance> _festivalByTithi({
    required String name,
    required String subtitle,
    required int tithi,
    required DateTime start,
    required DateTime end,
  }) {
    final out = <FestivalInstance>[];

    for (
      var d = _dayStart(start);
      !d.isAfter(_dayStart(end));
      d = d.add(const Duration(days: 1))
    ) {
      // Sample around "sunrise" in IST to reduce off-by-one issues.
      final sampleUtc = DateTime.utc(
        d.year,
        d.month,
        d.day,
        sunriseBoundaryHour,
        0,
        0,
      ).subtract(_istOffset);
      final info = _lunar.forMoment(sampleUtc);
      if (info.tithi == tithi) {
        out.add(FestivalInstance(localDay: d, title: name, subtitle: subtitle));
        break; // pick the first match in the window
      }
    }

    return out;
  }
}
