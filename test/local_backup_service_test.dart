import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_flutter/shared/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save/list/get restore points works', () async {
    final s = LocalBackupService.instance;

    final a = await s.saveRestorePoint(json: '{"v":1}', reason: 'test_a');
    final b = await s.saveRestorePoint(json: '{"v":2}', reason: 'test_b');

    final list = await s.listRestorePoints();
    expect(list.length, 2);

    // Newest first.
    expect(list.first.id, b.id);
    expect(list.last.id, a.id);

    final aJson = await s.getSnapshotJson(a.id);
    final bJson = await s.getSnapshotJson(b.id);

    expect(aJson, '{"v":1}');
    expect(bJson, '{"v":2}');
  });

  test('trims old snapshots past maxSnapshots', () async {
    final s = LocalBackupService.instance;

    final createdIds = <String>[];
    for (var i = 0; i < LocalBackupService.maxSnapshots + 2; i++) {
      final snap = await s.saveRestorePoint(json: '{"i":$i}', reason: 'test');
      createdIds.add(snap.id);
    }

    final list = await s.listRestorePoints();
    expect(list.length, LocalBackupService.maxSnapshots);

    // First created should be trimmed.
    final trimmedOldestId = createdIds.first;
    final trimmedSecondOldestId = createdIds[1];

    expect(await s.getSnapshotJson(trimmedOldestId), isNull);
    expect(await s.getSnapshotJson(trimmedSecondOldestId), isNull);

    // Most recent should exist.
    final newestId = createdIds.last;
    expect(await s.getSnapshotJson(newestId), isNotNull);
  });

  test('deleteSnapshot removes payload and index entry', () async {
    final s = LocalBackupService.instance;

    final a = await s.saveRestorePoint(json: '{"v":1}', reason: 'test');
    final b = await s.saveRestorePoint(json: '{"v":2}', reason: 'test');

    await s.deleteSnapshot(a.id);

    final list = await s.listRestorePoints();
    expect(list.length, 1);
    expect(list.single.id, b.id);

    expect(await s.getSnapshotJson(a.id), isNull);
    expect(await s.getSnapshotJson(b.id), '{"v":2}');
  });
}
