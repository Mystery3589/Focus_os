import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineFestivalInstance {
  final DateTime localDay;
  final String title;
  final String subtitle;

  const OnlineFestivalInstance({
    required this.localDay,
    required this.title,
    required this.subtitle,
  });

  Map<String, dynamic> toJson() => {
        'date': '${localDay.year.toString().padLeft(4, '0')}-${localDay.month.toString().padLeft(2, '0')}-${localDay.day.toString().padLeft(2, '0')}',
        'title': title,
        'subtitle': subtitle,
      };

  static OnlineFestivalInstance? fromJson(Map<String, dynamic> json) {
    try {
      final date = DateTime.parse(json['date'] as String);
      final title = (json['title'] as String?)?.trim();
      if (title == null || title.isEmpty) return null;
      final subtitle = (json['subtitle'] as String?)?.trim() ?? 'Online calendar';
      return OnlineFestivalInstance(
        localDay: DateTime(date.year, date.month, date.day),
        title: title,
        subtitle: subtitle,
      );
    } catch (_) {
      return null;
    }
  }
}

class OnlineFestivalCalendarData {
  final String? calendarName;
  final List<OnlineFestivalInstance> events;

  const OnlineFestivalCalendarData({required this.calendarName, required this.events});
}

/// Subscribes to a user-provided iCal (ICS) URL (read-only) and caches parsed results.
///
/// This is a flexible way to "link an online calendar" without needing an API key.
/// Users can paste public festival calendars (Google Calendar iCal links, etc.).
///
/// Privacy: this integration only performs HTTP GET to download the ICS text.
/// It never uploads your local events/meetings or writes back to any calendar.
class OnlineFestivalCalendarService {
  static final OnlineFestivalCalendarService instance = OnlineFestivalCalendarService._();
  OnlineFestivalCalendarService._();

  // We render lunar and festival dates in IST to keep India-centric calendars
  // consistent even when the device timezone differs (e.g. Windows setups).
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Default calendar (Google public holidays: India, English UK locale).
  ///
  /// User can change this anytime via the Calendar → Online link dialog.
  static const String defaultIndiaHolidaysIcsUrl =
      'https://calendar.google.com/calendar/ical/en-gb.indian%23holiday%40group.v.calendar.google.com/public/basic.ics';

  static const _prefsUrlKey = 'online_festival_ics_url';
  static const _prefsEnabledKey = 'online_festival_ics_enabled';
  static const _prefsDefaultAppliedKey = 'online_festival_ics_default_applied_v1';

  // Bump this when parsing changes, so older cached results are naturally
  // invalidated and re-fetched.
  static const _cacheVersion = 'v2';

  final _memCache = <String, OnlineFestivalCalendarData>{};

  bool _isTestMode() {
    // Flutter sets this compile-time environment constant for `flutter test`.
    // Do NOT use asserts to detect tests; asserts are enabled in debug runs too.
    return const bool.fromEnvironment('FLUTTER_TEST');
  }

  Future<String?> getIcsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsUrlKey);
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// Apply the built-in default calendar once (for fresh installs), without
  /// overwriting user choices.
  Future<void> ensureDefaultIndiaHolidaysLinked() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyApplied = prefs.getBool(_prefsDefaultAppliedKey) ?? false;
    if (alreadyApplied) return;

    final existingUrl = (prefs.getString(_prefsUrlKey) ?? '').trim();
    if (existingUrl.isNotEmpty) {
      await prefs.setBool(_prefsDefaultAppliedKey, true);
      return;
    }

    // Only set defaults when user hasn't configured anything yet.
    await prefs.setString(_prefsUrlKey, defaultIndiaHolidaysIcsUrl);
    await prefs.setBool(_prefsEnabledKey, true);
    await prefs.setBool(_prefsDefaultAppliedKey, true);
  }

  Future<void> setIcsUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final v = url?.trim();
    if (v == null || v.isEmpty) {
      await prefs.remove(_prefsUrlKey);
      return;
    }
    await prefs.setString(_prefsUrlKey, v);
  }

  Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);
  }

  Future<OnlineFestivalCalendarData> forYear({
    required int year,
    required String icsUrl,
  }) async {
    final url = icsUrl.trim();
    final cacheKey = '${_stableKey(url)}_$year';

    final inMem = _memCache[cacheKey];
    if (inMem != null) return inMem;

    final prefs = await SharedPreferences.getInstance();
    final prefsKey = 'online_festival_ics_${_cacheVersion}_${_stableKey(url)}_$year';

    final cached = prefs.getString(prefsKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = _decodeData(cached);
      _memCache[cacheKey] = decoded;
      return decoded;
    }

    if (_isTestMode()) {
      const empty = OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
      _memCache[cacheKey] = empty;
      return empty;
    }

    final fetched = await _fetchAndParseIcs(url: url, year: year);
    unawaited(prefs.setString(prefsKey, jsonEncode({
      'calendarName': fetched.calendarName,
      'events': fetched.events.map((e) => e.toJson()).toList(),
    })));

    _memCache[cacheKey] = fetched;
    return fetched;
  }

  /// Force-refresh a year's data from the network (clears caches first).
  ///
  /// Useful when the remote calendar changed and the user wants updates
  /// immediately.
  Future<OnlineFestivalCalendarData> refreshYear({
    required int year,
    required String icsUrl,
  }) async {
    final url = icsUrl.trim();
    final stable = _stableKey(url);
    final cacheKey = '${stable}_$year';
    final prefsKey = 'online_festival_ics_${_cacheVersion}_${stable}_$year';

    _memCache.remove(cacheKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);

    if (_isTestMode()) {
      const empty = OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
      _memCache[cacheKey] = empty;
      return empty;
    }

    final fetched = await _fetchAndParseIcs(url: url, year: year);
    unawaited(prefs.setString(
      prefsKey,
      jsonEncode({
        'calendarName': fetched.calendarName,
        'events': fetched.events.map((e) => e.toJson()).toList(),
      }),
    ));

    _memCache[cacheKey] = fetched;
    return fetched;
  }

  OnlineFestivalCalendarData _decodeData(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
      }
      final map = Map<String, dynamic>.from(decoded);
      final name = (map['calendarName'] as String?)?.trim();
      final eventsRaw = map['events'];
      if (eventsRaw is! List) {
        return OnlineFestivalCalendarData(calendarName: name, events: const <OnlineFestivalInstance>[]);
      }
      final out = <OnlineFestivalInstance>[];
      for (final e in eventsRaw) {
        if (e is Map<String, dynamic>) {
          final inst = OnlineFestivalInstance.fromJson(e);
          if (inst != null) out.add(inst);
        } else if (e is Map) {
          final inst = OnlineFestivalInstance.fromJson(Map<String, dynamic>.from(e));
          if (inst != null) out.add(inst);
        }
      }
      return OnlineFestivalCalendarData(calendarName: name, events: out);
    } catch (_) {
      return const OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
    }
  }

  String _stableKey(String url) {
    // FNV-1a 32-bit hash (stable across runs).
    var hash = 0x811C9DC5;
    for (final c in url.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<OnlineFestivalCalendarData> _fetchAndParseIcs({required String url, required int year}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return const OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
    }

    try {
      final client = HttpClient()..userAgent = 'focus_flutter/1.0 (calendar)';
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'text/calendar, text/plain, */*');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close(force: true);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('ICS fetch failed: ${resp.statusCode} $uri');
        }
        return const OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
      }

      return _parseIcs(body, year: year);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('ICS fetch error: $e');
      }
      return const OnlineFestivalCalendarData(calendarName: null, events: <OnlineFestivalInstance>[]);
    }
  }

  OnlineFestivalCalendarData _parseIcs(String raw, {required int year}) {
    final lines = _unfoldIcsLines(raw);

    String? calName;
    final out = <OnlineFestivalInstance>[];

    var inEvent = false;
    final event = <String, String>{};

    void flushEvent() {
      final summaryKey = event.keys.firstWhere(
        (k) => k.startsWith('SUMMARY'),
        orElse: () => '',
      );
      final summary = summaryKey.isEmpty ? null : event[summaryKey]?.trim();
      final dtStartKey = event.keys.firstWhere(
        (k) => k.startsWith('DTSTART'),
        orElse: () => '',
      );
      final dtStartRaw = dtStartKey.isEmpty ? null : event[dtStartKey];

      if (summary == null || summary.isEmpty || dtStartRaw == null) {
        event.clear();
        return;
      }

      final day = _parseIcsDate(dtStartRaw, dtStartKey: dtStartKey);
      if (day == null) {
        event.clear();
        return;
      }

      if (day.year != year) {
        // Keep yearly cache focused.
        event.clear();
        return;
      }

      out.add(
        OnlineFestivalInstance(
          localDay: DateTime(day.year, day.month, day.day),
          title: summary,
          subtitle: calName == null ? 'Online calendar' : 'Online • $calName',
        ),
      );

      event.clear();
    }

    for (final line in lines) {
      if (line.startsWith('X-WR-CALNAME:')) {
        calName = line.substring('X-WR-CALNAME:'.length).trim();
        continue;
      }

      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        event.clear();
        continue;
      }

      if (line == 'END:VEVENT') {
        if (inEvent) flushEvent();
        inEvent = false;
        continue;
      }

      if (!inEvent) continue;

      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1);

      // Keep first occurrence only (simple parser).
      event.putIfAbsent(key, () => value);
    }

    return OnlineFestivalCalendarData(calendarName: calName, events: out);
  }

  @visibleForTesting
  OnlineFestivalCalendarData parseIcsForYear(String raw, {required int year}) {
    return _parseIcs(raw, year: year);
  }

  List<String> _unfoldIcsLines(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final input = normalized.split('\n');
    final out = <String>[];

    for (final l in input) {
      if (l.isEmpty) continue;
      if (l.startsWith(' ') || l.startsWith('\t')) {
        if (out.isNotEmpty) {
          out[out.length - 1] = out.last + l.substring(1);
        }
      } else {
        out.add(l.trimRight());
      }
    }

    return out;
  }

  DateTime? _parseIcsDate(String value, {required String dtStartKey}) {
    // Examples:
    //  - DTSTART;VALUE=DATE:20260101
    //  - DTSTART:20260101T000000Z
    //  - DTSTART;TZID=Asia/Kolkata:20260101T000000
    // We only care about the day, but date-time entries may need timezone handling.
    final v = value.trim();
    if (v.length < 8) return null;

    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(4, 6));
    final d = int.tryParse(v.substring(6, 8));
    if (y == null || m == null || d == null) return null;

    final isDateOnly = dtStartKey.contains('VALUE=DATE') || !v.contains('T');
    if (isDateOnly) {
      return DateTime(y, m, d);
    }

    // If a time is present, parse it and map to an India-friendly local date.
    // Many public holiday calendars encode midnight as UTC (Z), which would
    // otherwise show up one day earlier for IST users.
    final tIndex = v.indexOf('T');
    if (tIndex < 0 || v.length < tIndex + 7) {
      return DateTime(y, m, d);
    }

    final hh = int.tryParse(v.substring(tIndex + 1, tIndex + 3)) ?? 0;
    final mm = int.tryParse(v.substring(tIndex + 3, tIndex + 5)) ?? 0;
    final ss = int.tryParse(v.substring(tIndex + 5, tIndex + 7)) ?? 0;

    final tzid = _extractTzId(dtStartKey);
    final isUtc = v.endsWith('Z');

    if (isUtc) {
      final dtUtc = DateTime.utc(y, m, d, hh, mm, ss);
      final dtIst = dtUtc.add(_istOffset);
      return DateTime(dtIst.year, dtIst.month, dtIst.day);
    }

    // If the event explicitly says it's in Kolkata/Calcutta timezone, treat it as IST.
    if (tzid == 'Asia/Kolkata' || tzid == 'Asia/Calcutta') {
      // The date component is already in that timezone; keep it as-is.
      return DateTime(y, m, d);
    }

    // Fallback: treat date-time entries as local calendar date.
    return DateTime(y, m, d);
  }

  String? _extractTzId(String key) {
    // DTSTART;TZID=Asia/Kolkata:...
    final idx = key.indexOf('TZID=');
    if (idx < 0) return null;
    var s = key.substring(idx + 'TZID='.length);
    final semi = s.indexOf(';');
    if (semi >= 0) s = s.substring(0, semi);
    final colon = s.indexOf(':');
    if (colon >= 0) s = s.substring(0, colon);
    final v = s.trim();
    return v.isEmpty ? null : v;
  }
}
