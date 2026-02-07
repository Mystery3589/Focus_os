import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  final String id;
  final String label;

  const DeviceIdentity({required this.id, required this.label});
}

/// Provides a stable per-install device id for cross-device sync semantics.
///
/// We intentionally avoid device-hardware identifiers and permissions.
class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const String _prefDeviceId = 'deviceIdentityId';
  static const String _prefDeviceLabel = 'deviceIdentityLabel';

  static const _uuid = Uuid();

  DeviceIdentity? _cache;

  Future<DeviceIdentity> getIdentity() async {
    final cached = _cache;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();

    var id = (prefs.getString(_prefDeviceId) ?? '').trim();
    if (id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_prefDeviceId, id);
    }

    var label = (prefs.getString(_prefDeviceLabel) ?? '').trim();
    if (label.isEmpty) {
      // Default label: platform + short id. User-friendly naming can be added later.
      final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
      label = '$platform ${id.substring(0, 4)}';
      await prefs.setString(_prefDeviceLabel, label);
    }

    final identity = DeviceIdentity(id: id, label: label);
    _cache = identity;
    return identity;
  }

  Future<void> setLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDeviceLabel, trimmed);

    final cur = await getIdentity();
    _cache = DeviceIdentity(id: cur.id, label: trimmed);
  }
}
