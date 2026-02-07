import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/providers/user_provider.dart';
import 'package:focus_flutter/shared/services/device_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('importUserStatsJson preserves local name when incoming name is blank', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);
    notifier.updateProfile(name: 'Alice');

    final before = container.read(userProvider);
    expect(before.name, 'Alice');

    final incoming = Map<String, dynamic>.from(before.toJson());
    incoming['name'] = '';

    await notifier.importUserStatsJson(jsonEncode(incoming));

    final after = container.read(userProvider);
    expect(after.name, 'Alice');
  });

  test('continueOpenSessionOnThisDevice closes/open segments and flips ownership', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    final myIdentity = await DeviceIdentityService.instance.getIdentity();

    notifier.addQuest(
      Quest(
        id: 'q_takeover_1',
        title: 'Takeover Quest',
        description: 'Test',
        reward: 'XP',
        progress: 0,
        difficulty: 'B',
        priority: 'B',
        expiry: '',
        expReward: 0,
        statPointsReward: 0,
        active: true,
        completed: false,
        expectedMinutes: 10,
        createdAt: 0,
      ),
    );

    // Create a real open session, then mutate it to look like it is running on
    // another device.
    expect(notifier.startFocus('q_takeover_1'), isTrue);

    final start = DateTime.now().millisecondsSinceEpoch - 60 * 1000;
    final base = container.read(userProvider).focus.openSessions.single;

    final mutated = FocusOpenSession(
      id: base.id,
      questId: base.questId,
      heading: base.heading,
      createdAt: base.createdAt,
      status: 'running',
      segments: [FocusSegment(startMs: start)],
      deviceId: 'other-device',
      deviceLabel: 'Other device',
      lastHeartbeatAtMs: start + 30 * 1000,
      nextBreakAtTotalMinutes: base.nextBreakAtTotalMinutes,
      breakOffers: base.breakOffers,
      breaksTaken: base.breaksTaken,
      breaksSkipped: base.breaksSkipped,
    );
    notifier.restoreOpenSession(mutated);

    final beforeMs = DateTime.now().millisecondsSinceEpoch;
    final ok = await notifier.continueOpenSessionOnThisDevice(base.id);
    final afterMs = DateTime.now().millisecondsSinceEpoch;

    expect(ok, isTrue);

    final stats = container.read(userProvider);
    expect(stats.focus.activeSessionId, base.id);

    final updated = stats.focus.openSessions.singleWhere((s) => s.id == base.id);
    expect(updated.status, 'running');

    // Ownership should switch to this device.
    expect(updated.deviceId, myIdentity.id);
    expect(updated.deviceLabel, myIdentity.label);

    // Continuity: previous open segment is closed, and a new segment starts.
    expect(updated.segments.length, 2);
    expect(updated.segments.first.startMs, start);
    expect(updated.segments.first.endMs, isNotNull);

    final closedAt = updated.segments.first.endMs!;
    expect(closedAt, inInclusiveRange(beforeMs, afterMs));
    expect(updated.segments.last.startMs, closedAt);
    expect(updated.segments.last.endMs, isNull);

    // Logs a takeover event.
    expect(
      stats.focusEvents.any((e) => e.type == 'focus_takeover' && e.sessionId == base.id),
      isTrue,
    );
  });
}
