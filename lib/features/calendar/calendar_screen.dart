import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geoengine/geoengine.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../shared/models/quest.dart';
import '../../shared/models/user_event.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/india_festival_service.dart';
import '../../shared/services/lunar_calendar_service.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/page_container.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late final LunarCalendarService _lunar;
  late final IndiaFestivalService _india;
  List<MoonQuarter> _moonQuarters = const [];
  bool _showLunarObservances = true;
  bool _showIndiaFestivals = true;
  bool _showChristianFestivals = true;
  bool _showObservances = true;
  List<FestivalInstance> _indiaFestivals = const [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    _lunar = LunarCalendarService();
    _india = IndiaFestivalService(_lunar);
    _moonQuarters = _computeMoonQuartersForMonth(_focusedDay);
    _indiaFestivals = _india.forMonth(_focusedDay);
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _nthWeekdayOfMonth({
    required int year,
    required int month,
    required int weekday,
    required int n,
  }) {
    // weekday uses DateTime.monday..DateTime.sunday.
    // Find the first occurrence of weekday in the month, then add (n-1) weeks.
    final first = DateTime(year, month, 1);
    final delta = (weekday - first.weekday) % 7;
    final day = 1 + delta + 7 * (n - 1);
    return DateTime(year, month, day);
  }

  List<({String title, String subtitle})> _observancesForDay(DateTime day) {
    final d = _dayStart(day);
    final y = d.year;

    // Common India/global observances (offline, deterministic rules).
    // Mother’s Day (India): 2nd Sunday of May.
    final mothersDay = _dayStart(_nthWeekdayOfMonth(
      year: y,
      month: 5,
      weekday: DateTime.sunday,
      n: 2,
    ));

    // Father’s Day (India): 3rd Sunday of June.
    final fathersDay = _dayStart(_nthWeekdayOfMonth(
      year: y,
      month: 6,
      weekday: DateTime.sunday,
      n: 3,
    ));

    // Friendship Day (India): 1st Sunday of August.
    final friendshipDay = _dayStart(_nthWeekdayOfMonth(
      year: y,
      month: 8,
      weekday: DateTime.sunday,
      n: 1,
    ));

    final out = <({String title, String subtitle})>[];
    if (_dayKey(d) == _dayKey(mothersDay)) out.add((title: "Mother's Day", subtitle: 'Observance (2nd Sunday of May)'));
    if (_dayKey(d) == _dayKey(fathersDay)) out.add((title: "Father's Day", subtitle: 'Observance (3rd Sunday of June)'));
    if (_dayKey(d) == _dayKey(friendshipDay)) out.add((title: 'Friendship Day', subtitle: 'Observance (1st Sunday of Aug)'));
    return out;
  }

  /// Gregorian Easter Sunday (Meeus/Jones/Butcher). Works for years in the Gregorian calendar.
  DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31; // 3=March, 4=April
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  List<({String title, String subtitle})> _christianMovableFestivalsForDay(DateTime day) {
    final d = _dayStart(day);
    final easter = _dayStart(_easterSunday(d.year));
    final goodFriday = easter.subtract(const Duration(days: 2));

    final out = <({String title, String subtitle})>[];
    if (_dayKey(d) == _dayKey(goodFriday)) {
      out.add((title: 'Good Friday', subtitle: 'Christian (movable)'));
    }
    if (_dayKey(d) == _dayKey(easter)) {
      out.add((title: 'Easter Sunday', subtitle: 'Christian (movable)'));
    }
    return out;
  }

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  DateTime _fromDayKey(int key) {
    final y = key ~/ 10000;
    final m = (key % 10000) ~/ 100;
    final dd = key % 100;
    return DateTime(y, m, dd);
  }

  /// Starter pack: fixed-date festivals. (Movable festivals can be added as custom events.)
  List<String> _fixedFestivalsForDay(DateTime day) {
    final m = day.month;
    final d = day.day;

    final out = <String>[];
    if (m == 1 && d == 1) out.add('New Year');
    if (m == 1 && d == 13) out.add('Lohri');
    if (m == 1 && d == 14) out.add('Makar Sankranti');
    if (m == 1 && d == 26) out.add('Republic Day');
    if (m == 2 && d == 14) out.add("Valentine's Day");
    if (m == 2 && d == 14) out.add('Black Day');
    if (m == 4 && d == 14) out.add('Ambedkar Jayanti');
    if (m == 5 && d == 1) out.add('Labour Day');
    if (m == 6 && d == 5) out.add('World Environment Day');
    if (m == 6 && d == 21) out.add('International Yoga Day');
    if (m == 8 && d == 15) out.add('Independence Day');
    if (m == 9 && d == 5) out.add("Teachers' Day");
    if (m == 10 && d == 2) out.add('Gandhi Jayanti');
    if (m == 11 && d == 14) out.add("Children's Day");
    if (m == 12 && d == 25) out.add('Christmas');
    if (m == 12 && d == 31) out.add("New Year's Eve");
    return out;
  }

  List<MoonQuarter> _computeMoonQuartersForMonth(DateTime focusedLocalDay) {
    final firstLocal = DateTime(focusedLocalDay.year, focusedLocalDay.month, 1);
    final lastLocal = DateTime(focusedLocalDay.year, focusedLocalDay.month + 1, 0);

    // Search a bit outside the month so edge events still appear.
    final startUtc = DateTime.utc(firstLocal.year, firstLocal.month, firstLocal.day)
        .subtract(const Duration(days: 2));
    final endUtc = DateTime.utc(lastLocal.year, lastLocal.month, lastLocal.day, 23, 59, 59)
        .add(const Duration(days: 2));

    final out = <MoonQuarter>[];

    MoonQuarter? mq;
    try {
      mq = MoonQuarter.searchMoonQuarter(startUtc);
    } catch (_) {
      mq = null;
    }

    // In practice you won't see more than ~4 quarter events/month.
    // We cap iterations to avoid accidental infinite loops.
    for (var i = 0; i < 48 && mq != null; i++) {
      final t = mq.time.date;
      if (t.isAfter(endUtc)) break;
      if (!t.isBefore(startUtc)) out.add(mq);

      try {
        mq = MoonQuarter.nextMoonQuarter(mq);
      } catch (_) {
        mq = null;
      }
    }

    return out;
  }

  List<_CalendarItem> _itemsForDay({
    required DateTime day,
    required List<UserEvent> userEvents,
    required List<Quest> quests,
    required List<MoonQuarter> moonQuarters,
    required List<FestivalInstance> indiaFestivals,
  }) {
    final key = _dayKey(day);

    final out = <_CalendarItem>[];

    final lunar = _lunar.forDay(day);

    for (final f in _fixedFestivalsForDay(day)) {
      out.add(_CalendarItem(
        type: _CalendarItemType.festival,
        title: f,
        subtitle: 'Festival',
      ));
    }

    if (_showObservances) {
      for (final o in _observancesForDay(day)) {
        out.add(_CalendarItem(
          type: _CalendarItemType.festival,
          title: o.title,
          subtitle: o.subtitle,
        ));
      }
    }

    if (_showChristianFestivals) {
      for (final f in _christianMovableFestivalsForDay(day)) {
        out.add(_CalendarItem(
          type: _CalendarItemType.festival,
          title: f.title,
          subtitle: f.subtitle,
        ));
      }
    }

    for (final f in indiaFestivals) {
      if (_dayKey(f.localDay) != key) continue;
      out.add(_CalendarItem(
        type: _CalendarItemType.festival,
        title: f.title,
        subtitle: 'India • ${f.subtitle}',
      ));
    }

    // Precise lunar quarter events (New/First/Full/Third) with local time.
    for (final mq in moonQuarters) {
      // Use IST for display + day assignment (independent of device timezone).
      final ist = mq.time.date.toUtc().add(_istOffset);
      final istDay = DateTime(ist.year, ist.month, ist.day);
      if (_dayKey(istDay) != key) continue;

      final hh = ist.hour.toString().padLeft(2, '0');
      final mm = ist.minute.toString().padLeft(2, '0');

      // Add friendlier Hindu labels where it makes sense.
      final title = switch (mq.quarterIndex) {
        0 => 'Amavasya (New Moon)',
        2 => 'Purnima (Full Moon)',
        _ => mq.quarter,
      };

      out.add(_CalendarItem(
        type: _CalendarItemType.moonQuarter,
        title: title,
        subtitle: 'Exact time (IST): $hh:$mm',
      ));
    }

    // Lunar observances (common recurring lunar "festivals"/vratas).
    // These are intentionally generic because many named festivals depend on
    // lunar month, regional traditions, and sunrise-based rules.
    if (_showLunarObservances) {
      final isEkadashi = lunar.tithi == 11 || lunar.tithi == 26;
      final isChaturthi = lunar.tithi == 4 || lunar.tithi == 19;
      final isAshtami = lunar.tithi == 8 || lunar.tithi == 23;
      final isPradoshLike = lunar.tithi == 13 || lunar.tithi == 28;

      if (isEkadashi) {
        out.add(_CalendarItem(
          type: _CalendarItemType.lunarFestival,
          title: '${lunar.paksha} Ekadashi',
          subtitle: 'Lunar observance (tithi ${lunar.tithi})',
        ));
      }
      if (isChaturthi) {
        out.add(_CalendarItem(
          type: _CalendarItemType.lunarFestival,
          title: '${lunar.paksha} Chaturthi',
          subtitle: 'Lunar observance (tithi ${lunar.tithi})',
        ));
      }
      if (isAshtami) {
        out.add(_CalendarItem(
          type: _CalendarItemType.lunarFestival,
          title: '${lunar.paksha} Ashtami',
          subtitle: 'Lunar observance (tithi ${lunar.tithi})',
        ));
      }
      if (isPradoshLike) {
        out.add(_CalendarItem(
          type: _CalendarItemType.lunarFestival,
          title: '${lunar.paksha} Trayodashi',
          subtitle: 'Lunar observance (tithi ${lunar.tithi})',
        ));
      }
    }

    // Always show lunar day info for the selected day.
    final illumPct = (lunar.illumination * 100).round();
    out.add(_CalendarItem(
      type: _CalendarItemType.lunarInfo,
      title: 'Lunar: ${lunar.paksha} ${lunar.tithiName}',
      subtitle: 'Tithi ${lunar.tithi} • Moon $illumPct% • Phase ${lunar.phaseAngleDeg.toStringAsFixed(0)}°',
    ));

    for (final q in quests) {
      if (q.completed) continue;
      if (q.startDateMs != null) {
        final start = _dayStart(DateTime.fromMillisecondsSinceEpoch(q.startDateMs!));
        if (_dayKey(start) == key) {
          out.add(_CalendarItem(
            type: _CalendarItemType.missionStart,
            title: q.title,
            subtitle: 'Mission starts',
            questId: q.id,
          ));
        }
      }
      if (q.dueDateMs != null) {
        final due = _dayStart(DateTime.fromMillisecondsSinceEpoch(q.dueDateMs!));
        if (_dayKey(due) == key) {
          out.add(_CalendarItem(
            type: _CalendarItemType.missionDue,
            title: q.title,
            subtitle: 'Mission due',
            questId: q.id,
          ));
        }
      }
    }

    for (final e in userEvents) {
      final d = _dayStart(DateTime.fromMillisecondsSinceEpoch(e.startAtMs));
      if (_dayKey(d) != key) continue;

      out.add(_CalendarItem(
        type: _CalendarItemType.userEvent,
        title: e.title,
        subtitle: e.allDay ? 'All-day event' : _formatTime(DateTime.fromMillisecondsSinceEpoch(e.startAtMs)),
        userEvent: e,
      ));
    }

    // Sort: festivals + lunar first, then events, then missions.
    out.sort((a, b) => a.type.index.compareTo(b.type.index));
    return out;
  }

  int _markerCountForDay({
    required DateTime day,
    required List<UserEvent> userEvents,
    required List<Quest> quests,
    required List<MoonQuarter> moonQuarters,
    required List<FestivalInstance> indiaFestivals,
  }) {
    // Do not count lunarInfo; otherwise every day gets a marker.
    final items = _itemsForDay(
      day: day,
      userEvents: userEvents,
      quests: quests,
      moonQuarters: moonQuarters,
      indiaFestivals: indiaFestivals,
    );
    return items.where((i) => i.type != _CalendarItemType.lunarInfo).length;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);

    final selected = _selectedDay ?? _dayStart(_focusedDay);
    final items = _itemsForDay(
      day: selected,
      userEvents: userStats.userEvents,
      quests: userStats.quests,
      moonQuarters: _moonQuarters,
      indiaFestivals: _showIndiaFestivals ? _indiaFestivals : const [],
    );

    final itemsByDayKey = <int, int>{};
    // Precompute counts for markers (current month range).
    final first = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final last = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    for (var d = _dayStart(first); !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final count = _markerCountForDay(
        day: d,
        userEvents: userStats.userEvents,
        quests: userStats.quests,
        moonQuarters: _moonQuarters,
        indiaFestivals: _showIndiaFestivals ? _indiaFestivals : const [],
      );
      if (count > 0) itemsByDayKey[_dayKey(d)] = count;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Calendar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          const AiInboxBellAction(),
          IconButton(
            tooltip: 'Add event',
            onPressed: () => _openEventDialog(initialDay: selected),
            icon: const Icon(LucideIcons.plusCircle),
          ),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              CyberCard(
                padding: const EdgeInsets.all(14),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = _dayStart(selectedDay);
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _moonQuarters = _computeMoonQuartersForMonth(focusedDay);
                      _indiaFestivals = _india.forMonth(focusedDay);
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                    weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
                    defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
                    outsideTextStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronIcon: Icon(LucideIcons.chevronLeft, color: AppTheme.textSecondary, size: 18),
                    rightChevronIcon: Icon(LucideIcons.chevronRight, color: AppTheme.textSecondary, size: 18),
                    titleTextStyle: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final k = _dayKey(day);
                      final count = itemsByDayKey[k] ?? 0;
                      if (count <= 0) return null;

                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 18,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              CyberCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 520;

                        final toggles = Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _showIndiaFestivals,
                                  onChanged: (v) => setState(() => _showIndiaFestivals = v),
                                  activeColor: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'India',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _showObservances,
                                  onChanged: (v) => setState(() => _showObservances = v),
                                  activeColor: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Obs',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _showChristianFestivals,
                                  onChanged: (v) => setState(() => _showChristianFestivals = v),
                                  activeColor: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Christian',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _showLunarObservances,
                                  onChanged: (v) => setState(() => _showLunarObservances = v),
                                  activeColor: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Lunar',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        );

                        final dateText = Text(
                          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.calendarDays, color: AppTheme.primary, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: dateText),
                                ],
                              ),
                              const SizedBox(height: 10),
                              toggles,
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _openEventDialog(initialDay: selected),
                                  child: const Text('Add event'),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            const Icon(LucideIcons.calendarDays, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: dateText),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: toggles,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _openEventDialog(initialDay: selected),
                              child: const Text('Add event'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No items for this day yet.\n\nTip: Movable festivals can be added as custom events.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                        ),
                      )
                    else
                      ...items.map((i) => _buildItemTile(context, i)).toList(),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, _CalendarItem item) {
    IconData icon;
    Color color;

    switch (item.type) {
      case _CalendarItemType.festival:
        icon = LucideIcons.sparkles;
        color = Colors.amberAccent;
        break;
      case _CalendarItemType.moonQuarter:
        icon = LucideIcons.moon;
        color = Colors.blueAccent;
        break;
      case _CalendarItemType.lunarFestival:
        icon = LucideIcons.sparkles;
        color = Colors.purpleAccent;
        break;
      case _CalendarItemType.lunarInfo:
        icon = LucideIcons.activity;
        color = Colors.tealAccent;
        break;
      case _CalendarItemType.userEvent:
        icon = LucideIcons.bookmark;
        color = AppTheme.primary;
        break;
      case _CalendarItemType.missionStart:
        icon = LucideIcons.flag;
        color = Colors.greenAccent;
        break;
      case _CalendarItemType.missionDue:
        icon = LucideIcons.alarmClock;
        color = Colors.redAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (item.userEvent?.notes != null && item.userEvent!.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.userEvent!.notes!.trim(),
                    style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95), fontSize: 12, height: 1.2),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (item.type == _CalendarItemType.userEvent && item.userEvent != null)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppTheme.textSecondary),
              onSelected: (v) {
                if (v == 'edit') {
                  _openEventDialog(initialDay: DateTime.fromMillisecondsSinceEpoch(item.userEvent!.startAtMs), existing: item.userEvent);
                } else if (v == 'delete') {
                  ref.read(userProvider.notifier).deleteUserEvent(item.userEvent!.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          else if ((item.type == _CalendarItemType.missionDue || item.type == _CalendarItemType.missionStart) && item.questId != null)
            IconButton(
              tooltip: 'Open mission',
              onPressed: () => context.go('/quests'),
              icon: const Icon(LucideIcons.externalLink, size: 18, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Future<void> _openEventDialog({
    required DateTime initialDay,
    UserEvent? existing,
  }) async {
    final now = DateTime.now();

    DateTime day = _dayStart(initialDay);
    TimeOfDay time = TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5);

    final title = TextEditingController(text: existing?.title ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');

    bool allDay = existing?.allDay ?? true;
    bool remind = existing?.remind ?? false;
    int remindMinutesBefore = existing?.remindMinutesBefore ?? 0;

    if (existing != null) {
      final startAt = DateTime.fromMillisecondsSinceEpoch(existing.startAtMs);
      day = _dayStart(startAt);
      time = TimeOfDay(hour: startAt.hour, minute: startAt.minute);
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String dayLabel(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

            Future<void> pickDay() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setState(() => day = _dayStart(picked));
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(context: context, initialTime: time);
              if (picked == null) return;
              setState(() => time = picked);
            }

            final trimmed = title.text.trim();
            final canSave = trimmed.isNotEmpty;

            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      existing == null ? 'Add event' : 'Edit event',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: AppTheme.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: title,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text('Notes (optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notes,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDay,
                              icon: const Icon(LucideIcons.calendar, size: 16),
                              label: Text(dayLabel(day)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: allDay ? null : pickTime,
                              icon: const Icon(LucideIcons.clock, size: 16),
                              label: Text(allDay ? 'All day' : time.format(context)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: allDay,
                        onChanged: (v) => setState(() => allDay = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('All-day', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),

                      const SizedBox(height: 4),
                      SwitchListTile(
                        value: remind,
                        onChanged: (v) => setState(() => remind = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remind me', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Requires Notifications + Event reminders enabled.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),
                      if (remind)
                        Row(
                          children: [
                            const Text('Minutes before:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 10),
                            DropdownButton<int>(
                              value: remindMinutesBefore,
                              dropdownColor: AppTheme.background,
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0')),
                                DropdownMenuItem(value: 10, child: Text('10')),
                                DropdownMenuItem(value: 30, child: Text('30')),
                                DropdownMenuItem(value: 60, child: Text('60')),
                              ],
                              onChanged: (v) => setState(() => remindMinutesBefore = v ?? 0),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                  onPressed: !canSave
                      ? null
                      : () {
                          final startAt = allDay
                              ? DateTime(day.year, day.month, day.day)
                              : DateTime(day.year, day.month, day.day, time.hour, time.minute);

                          final event = UserEvent(
                            id: existing?.id ?? '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
                            title: trimmed,
                            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                            startAtMs: startAt.millisecondsSinceEpoch,
                            allDay: allDay,
                            remind: remind,
                            remindMinutesBefore: remindMinutesBefore,
                          );

                          final notifier = ref.read(userProvider.notifier);
                          if (existing == null) {
                            notifier.addUserEvent(event);
                          } else {
                            notifier.updateUserEvent(event);
                          }

                          Navigator.of(context).pop();
                        },
                  child: Text(existing == null ? 'Add' : 'Save'),
                )
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      title.dispose();
      notes.dispose();
    });
  }
}

enum _CalendarItemType {
  // Lower index = earlier in sort.
  festival,
  moonQuarter,
  lunarFestival,
  lunarInfo,
  userEvent,
  missionStart,
  missionDue,
}

class _CalendarItem {
  final _CalendarItemType type;
  final String title;
  final String subtitle;
  final String? questId;
  final UserEvent? userEvent;

  const _CalendarItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.questId,
    this.userEvent,
  });
}
