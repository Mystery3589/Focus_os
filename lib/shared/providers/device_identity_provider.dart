import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_identity_service.dart';

final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  return DeviceIdentityService.instance.getIdentity();
});
