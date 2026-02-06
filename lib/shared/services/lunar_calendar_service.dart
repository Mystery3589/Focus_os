import 'package:geoengine/geoengine.dart';

class LunarDayInfo {
  final DateTime localDay;

  /// Moon phase angle in degrees [0, 360).
  ///
  /// 0 = New Moon, 90 = First Quarter, 180 = Full Moon, 270 = Third Quarter.
  final double phaseAngleDeg;

  /// Fraction illuminated [0, 1].
  final double illumination;

  /// Tithi number [1..30].
  /// Derived from the phase angle: tithi = floor(phase/12) + 1.
  final int tithi;

  /// "Shukla" for waxing (tithi 1..15), "Krishna" for waning (tithi 16..30).
  final String paksha;

  /// Human-readable name (e.g. "Pratipada", "Ekadashi", "Purnima").
  final String tithiName;

  const LunarDayInfo({
    required this.localDay,
    required this.phaseAngleDeg,
    required this.illumination,
    required this.tithi,
    required this.paksha,
    required this.tithiName,
  });
}

/// Lightweight lunar calculations for calendar display.
///
/// Uses GeoEngine's Astronomy Engine port to compute the Moon phase angle.
/// This gives a robust basis for:
/// - New/Full/Quarter moon events
/// - tithi (lunar day) approximation for a given local date/time sample
///
/// Note: A traditional Panchang is location-dependent (sunrise-based) and includes
/// ayanamsa, nakshatra, etc. We keep it intentionally simpler + MIT-licensed.
class LunarCalendarService {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  // Simple LRU cache by YYYYMMDD key.
  static const int _maxEntries = 512;
  final _cache = <int, LunarDayInfo>{};

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Returns lunar info for a day, sampling at 12:00 IST.
  ///
  /// We use a fixed IST sample to keep the app consistent with India calendars
  /// even if the device timezone is different.
  LunarDayInfo forDay(DateTime localDay) {
    final day = _dayStart(localDay);
    final key = _dayKey(day);

    final existing = _cache[key];
    if (existing != null) {
      // refresh LRU order
      _cache.remove(key);
      _cache[key] = existing;
      return existing;
    }

    // Use 12:00 IST to reduce boundary ambiguity vs midnight.
    // 12:00 IST == 06:30 UTC.
    final sampleUtc = DateTime.utc(day.year, day.month, day.day, 12, 0, 0).subtract(_istOffset);
    final time = AstroTime(sampleUtc);

    final phase = moonPhase(time); // degrees
    final illum = IlluminationInfo.getBodyIllumination(Body.Moon, time).phaseFraction;

    // Convert phase angle to a tithi number [1..30].
    // Each tithi spans 12 degrees of elongation.
    var tithi = (phase / 12.0).floor() + 1;
    if (tithi < 1) tithi = 1;
    if (tithi > 30) tithi = 30;

    final paksha = tithi <= 15 ? 'Shukla' : 'Krishna';
    final name = _tithiName(tithi);

    final info = LunarDayInfo(
      localDay: day,
      phaseAngleDeg: phase,
      illumination: illum,
      tithi: tithi,
      paksha: paksha,
      tithiName: name,
    );

    _cache[key] = info;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    return info;
  }

  /// Returns lunar info sampled at an arbitrary date/time.
  ///
  /// This is useful for sunrise-based heuristics used by some festival rules.
  /// Note: This is intentionally not cached because it may be called with many
  /// different times for the same day.
  LunarDayInfo forMoment(DateTime localDateTime) {
    final day = _dayStart(localDateTime);

    // If caller provides UTC, toUtc() is a no-op.
    final sampleUtc = localDateTime.toUtc();
    final time = AstroTime(sampleUtc);

    final phase = moonPhase(time); // degrees
    final illum = IlluminationInfo.getBodyIllumination(Body.Moon, time).phaseFraction;

    var tithi = (phase / 12.0).floor() + 1;
    if (tithi < 1) tithi = 1;
    if (tithi > 30) tithi = 30;

    final paksha = tithi <= 15 ? 'Shukla' : 'Krishna';
    final name = _tithiName(tithi);

    return LunarDayInfo(
      localDay: day,
      phaseAngleDeg: phase,
      illumination: illum,
      tithi: tithi,
      paksha: paksha,
      tithiName: name,
    );
  }

  static String _tithiName(int tithi) {
    // Names are widely used, generic, and not locale-specific.
    // 1-15 repeat for Krishna paksha (16..30), but we keep the canonical names.
    switch (tithi) {
      case 1:
      case 16:
        return 'Pratipada';
      case 2:
      case 17:
        return 'Dvitiya';
      case 3:
      case 18:
        return 'Tritiya';
      case 4:
      case 19:
        return 'Chaturthi';
      case 5:
      case 20:
        return 'Panchami';
      case 6:
      case 21:
        return 'Shashthi';
      case 7:
      case 22:
        return 'Saptami';
      case 8:
      case 23:
        return 'Ashtami';
      case 9:
      case 24:
        return 'Navami';
      case 10:
      case 25:
        return 'Dashami';
      case 11:
      case 26:
        return 'Ekadashi';
      case 12:
      case 27:
        return 'Dwadashi';
      case 13:
      case 28:
        return 'Trayodashi';
      case 14:
      case 29:
        return 'Chaturdashi';
      case 15:
        return 'Purnima';
      case 30:
        return 'Amavasya';
      default:
        return 'Tithi';
    }
  }
}
