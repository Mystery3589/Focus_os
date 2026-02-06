import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'white_noise_synth.dart';

/// Plays a short tick/click sound for the Flip clock.
///
/// This is intentionally:
/// - tiny (generated WAV)
/// - offline
/// - test-safe (no-op in widget tests)
class FlipClockSoundService {
  FlipClockSoundService._();

  static final FlipClockSoundService instance = FlipClockSoundService._();

  final AudioPlayer _player = AudioPlayer();

  Uint8List? _tickWav;
  bool _configured = false;

  bool get _isTestEnv {
    // Avoid importing flutter_test into lib/ code.
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') ||
        name.contains('AutomatedTestWidgetsFlutterBinding');
  }

  Future<void> tick({double volume = 0.25}) async {
    if (_isTestEnv) return;

    try {
      if (!_configured) {
        await _player.setReleaseMode(ReleaseMode.stop);
        _configured = true;
      }

      _tickWav ??= WhiteNoiseSynth.generateFlipTickWav();

      // Stop any previous tick so rapid rebuilds don't stack sounds.
      await _player.stop();
      await _player.play(BytesSource(_tickWav!), volume: volume);
    } catch (_) {
      // Keep UI usable even if audio fails.
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // ignore
    }
  }
}
