import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/focus_session.dart';

void main() {
  group('WhiteNoiseSettings JSON', () {
    test('fromJson is backward-compatible and clamps volume', () {
      final s = WhiteNoiseSettings.fromJson({
        'enabled': true,
        'preset': 'custom',
        'volume': 99, // should clamp
        'customPath': 'C:/tmp/sound.wav',
        // legacy/unknown keys should not crash decoding
        'thunderstormOverridePath': 'C:/tmp/old_override.wav',
      });

      expect(s.enabled, isTrue);
      expect(s.preset, 'custom');
      expect(s.volume, 1.0);
      expect(s.customPath, 'C:/tmp/sound.wav');
    });

    test('roundtrip preserves known fields', () {
      const s = WhiteNoiseSettings(
        enabled: true,
        preset: 'thunderstorm',
        volume: 0.5,
        customPath: null,
      );

      final json = s.toJson();
      final decoded = WhiteNoiseSettings.fromJson(json);

      expect(decoded.preset, 'thunderstorm');
      expect(decoded.volume, closeTo(0.5, 1e-9));
    });
  });
}
