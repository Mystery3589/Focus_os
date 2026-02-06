import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;

  // Sound paths
  // Note: assets/sounds/ may be empty on some installs; use assets/audio/ for shipped SFX.
  static const String levelUpSound = 'audio/glitch-screen.mp3';
  static const String buttonClickSound = 'audio/tick.mp3';
  static const String questCompleteSound = 'audio/tick.mp3';

  /// Play a sound effect
  Future<void> playSound(String soundPath) async {
    if (!_isEnabled) return;

    try {
      await _player.stop(); // Stop any currently playing sound
      await _player.play(AssetSource(soundPath));
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound $soundPath: $e');
      }
    }
  }

  /// Play level-up sound
  Future<void> playLevelUp() async {
    await playSound(levelUpSound);
  }

  /// Play button click sound
  Future<void> playButtonClick() async {
    // Only play if you have the sound file
    // await playSound(buttonClickSound);
  }

  /// Play quest complete sound
  Future<void> playQuestComplete() async {
    // Only play if you have the sound file
    // await playSound(questCompleteSound);
  }

  /// Enable/disable all sounds
  void setSoundEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if sounds are enabled
  bool get isEnabled => _isEnabled;

  /// Dispose the player when done
  void dispose() {
    _player.dispose();
  }
}
