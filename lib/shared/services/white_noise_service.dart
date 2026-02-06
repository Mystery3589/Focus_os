
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/focus_session.dart';
import 'white_noise_synth.dart';

/// Background white-noise playback for the Focus screen.
///
/// Design goals:
/// - Offline friendly (no network)
/// - Test safe (never crashes widget tests if plugins aren't available)
/// - No bundled audio required for presets: rain + thunderstorm are generated as WAV bytes.
class WhiteNoiseService {
  WhiteNoiseService._();

  static final WhiteNoiseService instance = WhiteNoiseService._();

  final AudioPlayer _player = AudioPlayer();

  String? _appliedKey;
  Uint8List? _rainWav;
  Uint8List? _thunderWav;

  bool get _isTestEnv {
    // Avoid importing flutter_test into lib/ code.
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') || name.contains('AutomatedTestWidgetsFlutterBinding');
  }

  Future<void> apply(WhiteNoiseSettings settings) async {
    if (_isTestEnv) return;

    final preset = settings.preset;
    final enabled = settings.enabled && preset != 'off';
    final vol = settings.volume.clamp(0.0, 1.0);

    final key = '${enabled ? 1 : 0}|$preset|${settings.customPath ?? ''}';

    // Volume is safe to update even if the source is unchanged.
    try {
      await _player.setVolume(vol);
    } catch (_) {
      // ignore (plugin may be unavailable on some platforms during startup)
    }

    if (!enabled) {
      await stop();
      _appliedKey = key;
      return;
    }

    // If same source already applied, no need to restart playback.
    if (_appliedKey == key) return;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);

      Future<void> playThunderstormFallback() async {
        // Try a bundled MP3 first (lets you replace the built-in thunderstorm).
        // NOTE: This project uses `AssetSource()` paths without the `assets/`
        // prefix (see SoundManager: 'sounds/...').
        const candidates = <String>[
          'audio/whitenoise.mp3',
          'audio/thunderstorm.mp3',
          'audio/thunderstrom.mp3',
        ];

        for (final p in candidates) {
          try {
            await _player.play(AssetSource(p), volume: vol);
            if (kDebugMode) {
              // ignore: avoid_print
              print('WhiteNoiseService: playing thunderstorm asset: $p');
            }
            return;
          } catch (_) {
            // Try next.
          }
        }

        // Offline fallback (always available).
        if (kDebugMode) {
          // ignore: avoid_print
          print('WhiteNoiseService: thunderstorm asset missing, using offline synth');
        }
        await _player.play(BytesSource(_presetWav('thunderstorm')), volume: vol);
      }

      final Source src;
      if (preset == 'custom') {
        final path = settings.customPath;
        if (path == null || path.trim().isEmpty) {
          // No custom file chosen yet; fallback.
          await playThunderstormFallback();
          _appliedKey = key;
          return;
        } else {
          try {
            await _player.play(DeviceFileSource(path), volume: vol);
            _appliedKey = key;
            return;
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('WhiteNoiseService: custom file failed, falling back ($e)');
            }
            await playThunderstormFallback();
            _appliedKey = key;
            return;
          }
        }
      } else if (preset == 'thunder' || preset == 'thunderstorm') {
        await playThunderstormFallback();

        _appliedKey = key;
        return;
      } else {
        src = BytesSource(_presetWav(preset));
      }

      await _player.play(src, volume: vol);
      _appliedKey = key;
    } catch (e) {
      if (kDebugMode) {
        // Keep app usable even if audio fails.
        // ignore: avoid_print
        print('WhiteNoiseService.apply() failed: $e');
      }
    }
  }

  Future<void> stop() async {
    if (_isTestEnv) return;
    // Clear the cached key so a subsequent `apply()` with the same settings
    // actually restarts playback (important for the Focus screen pause/resume
    // button which calls `stop()` directly).
    _appliedKey = null;
    try {
      await _player.stop();
    } catch (_) {
      // ignore
    }
  }

  Uint8List _presetWav(String preset) {
    switch (preset) {
      case 'thunder':
      case 'thunderstorm':
        return _thunderWav ??= WhiteNoiseSynth.generateThunderstormWav();
      case 'rain':
      default:
        return _rainWav ??= WhiteNoiseSynth.generateRainWav();
    }
  }
}
