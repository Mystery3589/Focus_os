import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PublicHolidayInstance {
  final DateTime localDay;
  final String title;
  final String subtitle;

  const PublicHolidayInstance({
    required this.localDay,
    required this.title,
    required this.subtitle,
  });

  Map<String, dynamic> toJson() => {
        'date': '${localDay.year.toString().padLeft(4, '0')}-${localDay.month.toString().padLeft(2, '0')}-${localDay.day.toString().padLeft(2, '0')}',
        'title': title,
        'subtitle': subtitle,
      };

  static PublicHolidayInstance? fromJson(Map<String, dynamic> json) {
    try {
      final date = DateTime.parse(json['date'] as String);
      final title = (json['title'] as String?)?.trim();
      if (title == null || title.isEmpty) return null;
      final subtitle = (json['subtitle'] as String?)?.trim() ?? 'Public holiday';
      return PublicHolidayInstance(localDay: DateTime(date.year, date.month, date.day), title: title, subtitle: subtitle);
    } catch (_) {
      return null;
    }
  }
}

/// Fetches and caches yearly public holidays by country.
///
/// Uses the free, no-key Nager.Date API:
/// https://date.nager.at
///
/// Note: This covers official public holidays, not region-specific festival
/// calendars/panchang.
class PublicHolidayService {
  static final PublicHolidayService instance = PublicHolidayService._();
  PublicHolidayService._();

  final _memCache = <String, List<PublicHolidayInstance>>{};

  String _prefsKey({required String countryCode, required int year}) => 'public_holidays_${countryCode.toUpperCase()}_$year';

  bool _isTestMode() {
    // Flutter sets this compile-time environment constant for `flutter test`.
    // Do NOT use asserts to detect tests; asserts are enabled in debug runs too.
    return const bool.fromEnvironment('FLUTTER_TEST');
  }

  Future<List<PublicHolidayInstance>> forYear({required int year, String countryCode = 'IN'}) async {
    final cc = countryCode.toUpperCase();
    final key = _prefsKey(countryCode: cc, year: year);

    final inMem = _memCache[key];
    if (inMem != null) return inMem;

    final prefs = await SharedPreferences.getInstance();

    // Try cache first.
    final cached = prefs.getString(key);
    if (cached != null && cached.trim().isNotEmpty) {
      final parsed = _decodeHolidayList(cached);
      _memCache[key] = parsed;
      return parsed;
    }

    // Avoid network in tests to keep them deterministic/fast.
    if (_isTestMode()) {
      _memCache[key] = const [];
      return const [];
    }

    final fetched = await _fetchFromNager(year: year, countryCode: cc);
    if (fetched.isNotEmpty) {
      unawaited(prefs.setString(key, jsonEncode(fetched.map((e) => e.toJson()).toList())));
    }
    _memCache[key] = fetched;
    return fetched;
  }

  Future<void> prefetch({required int year, String countryCode = 'IN'}) async {
    try {
      await forYear(year: year, countryCode: countryCode);
    } catch (_) {
      // ignore
    }
  }

  List<PublicHolidayInstance> _decodeHolidayList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <PublicHolidayInstance>[];
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          final inst = PublicHolidayInstance.fromJson(e);
          if (inst != null) out.add(inst);
        } else if (e is Map) {
          final inst = PublicHolidayInstance.fromJson(Map<String, dynamic>.from(e));
          if (inst != null) out.add(inst);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<PublicHolidayInstance>> _fetchFromNager({required int year, required String countryCode}) async {
    final uri = Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/$countryCode');

    try {
      final client = HttpClient()..userAgent = 'focus_flutter/1.0 (calendar)';
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close(force: true);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Holiday fetch failed: ${resp.statusCode} $uri');
        }
        return const [];
      }

      // Some networks/proxies can return a 200 with an empty body (or a non-JSON body).
      // Avoid throwing a FormatException from jsonDecode in that case.
      final trimmed = body.trim();
      if (trimmed.isEmpty) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Holiday fetch returned empty body: ${resp.statusCode} $uri');
        }
        return const [];
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return const [];

      final out = <PublicHolidayInstance>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final dateStr = map['date'] as String?;
        if (dateStr == null) continue;

        final localName = (map['localName'] as String?)?.trim();
        final name = (map['name'] as String?)?.trim();
        final title = (localName?.isNotEmpty ?? false) ? localName! : (name ?? '').trim();
        if (title.isEmpty) continue;

        DateTime day;
        try {
          final d = DateTime.parse(dateStr);
          day = DateTime(d.year, d.month, d.day);
        } catch (_) {
          continue;
        }

        out.add(PublicHolidayInstance(localDay: day, title: title, subtitle: 'Public holiday • $countryCode'));
      }

      return out;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Holiday fetch error: $e');
      }
      return const [];
    }
  }
}
