import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalBackupSnapshot {
  final String id;
  final int createdAtMs;
  final String reason;

  const LocalBackupSnapshot({
    required this.id,
    required this.createdAtMs,
    required this.reason,
  });

  factory LocalBackupSnapshot.fromJson(Map<String, dynamic> json) {
    return LocalBackupSnapshot(
      id: json['id'] as String,
      createdAtMs: (json['createdAtMs'] as num).toInt(),
      reason: (json['reason'] as String?) ?? 'restore_point',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAtMs': createdAtMs,
      'reason': reason,
    };
  }
}

/// Local restore points stored in SharedPreferences.
///
/// This is meant as a safety net for destructive imports (cloud restore, manual import).
class LocalBackupService {
  LocalBackupService._();

  static final LocalBackupService instance = LocalBackupService._();

  static const String _indexKey = 'localBackupSnapshotsIndex';
  static const String _payloadPrefix = 'localBackupSnapshot:';

  /// Keep a small history so storage doesn't grow unbounded.
  static const int maxSnapshots = 6;

  static const _uuid = Uuid();

  Future<LocalBackupSnapshot> saveRestorePoint({
    required String json,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final id = _uuid.v4();
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;

    final snap = LocalBackupSnapshot(id: id, createdAtMs: createdAtMs, reason: reason);

    // Persist payload.
    await prefs.setString('$_payloadPrefix$id', json);

    // Update index.
    final existing = await listRestorePoints();
    final next = <LocalBackupSnapshot>[snap, ...existing];

    // Trim old snapshots and delete payloads.
    if (next.length > maxSnapshots) {
      final toRemove = next.sublist(maxSnapshots);
      for (final r in toRemove) {
        await prefs.remove('$_payloadPrefix${r.id}');
      }
    }

    final trimmed = next.take(maxSnapshots).toList(growable: false);
    await prefs.setString(_indexKey, jsonEncode(trimmed.map((s) => s.toJson()).toList()));

    return snap;
  }

  Future<List<LocalBackupSnapshot>> listRestorePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => LocalBackupSnapshot.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> getSnapshotJson(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_payloadPrefix$id');
  }

  Future<void> deleteSnapshot(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_payloadPrefix$id');

    final existing = await listRestorePoints();
    final next = existing.where((s) => s.id != id).toList(growable: false);
    await prefs.setString(_indexKey, jsonEncode(next.map((s) => s.toJson()).toList()));
  }
}
