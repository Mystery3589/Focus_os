import 'dart:math' as math;
import 'dart:typed_data';

/// Offline white-noise synthesis helpers.
///
/// Returns mono 16-bit PCM WAV bytes.
class WhiteNoiseSynth {
  /// Rain bed + distinct droplet "plinks".
  static Uint8List generateRainWav({
    int seconds = 18,
    int sampleRate = 44100,
    int seed = 1337,
  }) {
    final totalSamples = seconds * sampleRate;
    final rng = math.Random(seed);

    // Paul Kellet-ish pink noise filter state (approx).
    double b0 = 0, b1 = 0, b2 = 0;

    // One-pole low-pass for body.
    double lp = 0.0;
    const lpAlpha = 0.02;

    // Brown-ish drift for low movement.
    double brown = 0.0;

    // Droplet voices (short resonant decays).
    final droplets = <_DropletVoice>[];

    // Event rates (per second).
    const dripRate = 2.7; // clear droplets
    const splashRate = 0.55; // chunkier drops

    final pcm = Int16List(totalSamples);

    for (var i = 0; i < totalSamples; i++) {
      // Base noise.
      final w = rng.nextDouble() * 2.0 - 1.0;

      // Pink-ish: run through simple IIR bank.
      // (Not perfect, but noticeably less harsh than white.)
      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.96900 * b2 + w * 0.1538520;
      final pink = (b0 + b1 + b2 + w * 0.3104856);

      // Body: low-pass some of the noise.
      lp = lp + lpAlpha * (pink - lp);
      final hp = pink - lp;

      brown = (brown + (w * 0.015)).clamp(-1.0, 1.0);

      // Schedule droplets.
      if (rng.nextDouble() < dripRate / sampleRate) {
        droplets.add(_DropletVoice.plink(rng: rng, sampleRate: sampleRate));
      }
      if (rng.nextDouble() < splashRate / sampleRate) {
        droplets.add(_DropletVoice.splash(rng: rng, sampleRate: sampleRate));
      }

      // Mix droplets.
      double dropletSum = 0.0;
      for (int d = droplets.length - 1; d >= 0; d--) {
        final v = droplets[d];
        dropletSum += v.nextSample(rng);
        if (v.done) droplets.removeAt(d);
      }

      // Bed mix: airy hiss + body + drift.
      // Droplets are more distinct, so keep them moderate.
      var s = hp * 0.42 + lp * 0.24 + brown * 0.12 + dropletSum * 0.60;

      // Slight dynamics: reduce harshness on peaks.
      s = _softClip(s, drive: 1.10);

      pcm[i] = (s.clamp(-1.0, 1.0) * 32767.0).toInt();
    }

    return _wavFromPcm16Mono(pcm, sampleRate: sampleRate);
  }

  /// Thunderstorm = rain bed + occasional thunder (crack + delayed rumble).
  static Uint8List generateThunderstormWav({
    int seconds = 18,
    int sampleRate = 44100,
    int seed = 9001,
  }) {
    final totalSamples = seconds * sampleRate;
    final rng = math.Random(seed);

    // Reuse rain synthesis components.
    double b0 = 0, b1 = 0, b2 = 0;
    double lp = 0.0;
    const lpAlpha = 0.02;
    double brown = 0.0;

    final droplets = <_DropletVoice>[];
    const dripRate = 2.1;
    const splashRate = 0.45;

    // Thunder events.
    final thunders = _scheduleThunderEvents(rng: rng, seconds: seconds, sampleRate: sampleRate);

    final pcm = Int16List(totalSamples);

    for (var i = 0; i < totalSamples; i++) {
      final w = rng.nextDouble() * 2.0 - 1.0;

      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.96900 * b2 + w * 0.1538520;
      final pink = (b0 + b1 + b2 + w * 0.3104856);

      // Slightly heavier storm: more body, less hiss.
      lp = lp + lpAlpha * (pink - lp);
      final hp = pink - lp;
      brown = (brown + (w * 0.018)).clamp(-1.0, 1.0);

      if (rng.nextDouble() < dripRate / sampleRate) {
        droplets.add(_DropletVoice.plink(rng: rng, sampleRate: sampleRate));
      }
      if (rng.nextDouble() < splashRate / sampleRate) {
        droplets.add(_DropletVoice.splash(rng: rng, sampleRate: sampleRate));
      }

      double dropletSum = 0.0;
      for (int d = droplets.length - 1; d >= 0; d--) {
        final v = droplets[d];
        dropletSum += v.nextSample(rng);
        if (v.done) droplets.removeAt(d);
      }

      // Thunder mix.
      double thunderSum = 0.0;
      for (int t = thunders.length - 1; t >= 0; t--) {
        final ev = thunders[t];
        thunderSum += ev.sampleAt(i, rng);
      }

      var s = hp * 0.32 + lp * 0.30 + brown * 0.18 + dropletSum * 0.55 + thunderSum * 0.75;
      s = _softClip(s, drive: 1.15);

      pcm[i] = (s.clamp(-1.0, 1.0) * 32767.0).toInt();
    }

    return _wavFromPcm16Mono(pcm, sampleRate: sampleRate);
  }

  /// A tiny, crisp tick/click sound for the Flip clock.
  ///
  /// Returns mono 16-bit PCM WAV bytes.
  static Uint8List generateFlipTickWav({
    int sampleRate = 44100,
    int milliseconds = 42,
  }) {
    final totalSamples = (milliseconds * sampleRate / 1000.0).round().clamp(1, sampleRate);
    final pcm = Int16List(totalSamples);

    // A short, damped high-frequency sine plus a touch of noise.
    const freqHz = 1800.0;
    const amp = 0.35;
    double phase = 0.0;
    final phaseInc = 2.0 * math.pi * freqHz / sampleRate;

    final rng = math.Random(4242);

    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // Fast decay; keep it snappy.
      final env = math.exp(-t * 85.0);
      final sine = math.sin(phase) * env;
      phase += phaseInc;

      final noise = ((rng.nextDouble() * 2.0 - 1.0) * 0.25) * env;
      var s = (sine * 0.85 + noise * 0.15) * amp;
      s = _softClip(s, drive: 1.2);
      pcm[i] = (s.clamp(-1.0, 1.0) * 32767.0).toInt();
    }

    return _wavFromPcm16Mono(pcm, sampleRate: sampleRate);
  }

  static List<_ThunderEvent> _scheduleThunderEvents({
    required math.Random rng,
    required int seconds,
    required int sampleRate,
  }) {
    // Pick 3-5 events with spacing so they feel "in between".
    final count = 3 + rng.nextInt(3);
    final minGapSec = 3.0;
    final events = <_ThunderEvent>[];

    final starts = <double>[];
    int guard = 0;
    while (starts.length < count && guard < 2000) {
      guard++;
      final t = 1.2 + rng.nextDouble() * (seconds - 3.2);
      if (starts.every((x) => (x - t).abs() >= minGapSec)) {
        starts.add(t);
      }
    }
    starts.sort();

    for (final t in starts) {
      final startSample = (t * sampleRate).toInt();
      final crackMs = 25 + rng.nextInt(30); // 25-55ms
      final delayMs = 120 + rng.nextInt(320); // delay crack->rumble
      final rumbleMs = 2200 + rng.nextInt(2600); // 2.2-4.8s

      final baseFreq = 28.0 + rng.nextDouble() * 22.0; // 28-50Hz
      final amp = 0.30 + rng.nextDouble() * 0.35;

      events.add(
        _ThunderEvent(
          startSample: startSample,
          crackSamples: (crackMs * sampleRate / 1000.0).round(),
          rumbleDelaySamples: (delayMs * sampleRate / 1000.0).round(),
          rumbleSamples: (rumbleMs * sampleRate / 1000.0).round(),
          baseFreqHz: baseFreq,
          amp: amp,
        ),
      );
    }

    return events;
  }
}

class _DropletVoice {
  int remaining;
  double amp;
  double phase;
  final double phaseInc;
  final double decay;
  final double noiseMix;

  _DropletVoice({
    required this.remaining,
    required this.amp,
    required this.phase,
    required this.phaseInc,
    required this.decay,
    required this.noiseMix,
  });

  bool get done => remaining <= 0 || amp < 0.0005;

  double nextSample(math.Random rng) {
    if (remaining <= 0) return 0.0;

    // A resonant ring with a touch of noisy "drop".
    final s = math.sin(phase) * amp;
    final n = (rng.nextDouble() * 2.0 - 1.0) * amp * noiseMix;

    phase += phaseInc;
    amp *= decay;
    remaining -= 1;

    return s + n;
  }

  static _DropletVoice plink({required math.Random rng, required int sampleRate}) {
    final durMs = 65 + rng.nextInt(90); // 65-155ms
    final remaining = (durMs * sampleRate / 1000.0).round();
    final freq = 900.0 + rng.nextDouble() * 1400.0; // 0.9-2.3kHz
    final amp = 0.07 + rng.nextDouble() * 0.14;
    final decay = 0.9965 + rng.nextDouble() * 0.0018; // slow-ish decay
    final noiseMix = 0.18 + rng.nextDouble() * 0.18;

    return _DropletVoice(
      remaining: remaining,
      amp: amp,
      phase: rng.nextDouble() * math.pi * 2.0,
      phaseInc: 2.0 * math.pi * freq / sampleRate,
      decay: decay,
      noiseMix: noiseMix,
    );
  }

  static _DropletVoice splash({required math.Random rng, required int sampleRate}) {
    final durMs = 35 + rng.nextInt(60); // 35-95ms
    final remaining = (durMs * sampleRate / 1000.0).round();
    final freq = 260.0 + rng.nextDouble() * 520.0; // 260-780Hz
    final amp = 0.06 + rng.nextDouble() * 0.10;
    final decay = 0.9940 + rng.nextDouble() * 0.0025;
    final noiseMix = 0.40 + rng.nextDouble() * 0.25;

    return _DropletVoice(
      remaining: remaining,
      amp: amp,
      phase: rng.nextDouble() * math.pi * 2.0,
      phaseInc: 2.0 * math.pi * freq / sampleRate,
      decay: decay,
      noiseMix: noiseMix,
    );
  }
}

class _ThunderEvent {
  final int startSample;
  final int crackSamples;
  final int rumbleDelaySamples;
  final int rumbleSamples;
  final double baseFreqHz;
  final double amp;

  // State for rumble low-pass noise.
  double _lp = 0.0;

  _ThunderEvent({
    required this.startSample,
    required this.crackSamples,
    required this.rumbleDelaySamples,
    required this.rumbleSamples,
    required this.baseFreqHz,
    required this.amp,
  });

  double sampleAt(int i, math.Random rng) {
    if (i < startSample) return 0.0;
    final local = i - startSample;

    double s = 0.0;

    // Lightning crack: short, bright noise burst.
    if (local >= 0 && local < crackSamples) {
      final t = local / math.max(1, crackSamples);
      final env = math.pow(1.0 - t, 3.0).toDouble();
      final n = rng.nextDouble() * 2.0 - 1.0;
      // Add a small high-frequency ring to help it cut through.
      final ring = math.sin(2.0 * math.pi * (1200.0 + 800.0 * rng.nextDouble()) * (local / 44100.0));
      s += (n * 0.65 + ring * 0.35) * env * amp * 0.85;
    }

    // Rumble: delayed and long decay.
    final rumbleStart = rumbleDelaySamples;
    final rumbleLocal = local - rumbleStart;
    if (rumbleLocal >= 0 && rumbleLocal < rumbleSamples) {
      final t = rumbleLocal / 44100.0;
      final env = math.exp(-t * 0.85);

      // Low-frequency oscillation(s).
      final sine1 = math.sin(2.0 * math.pi * baseFreqHz * t);
      final sine2 = math.sin(2.0 * math.pi * (baseFreqHz * 0.66) * t);

      // Low-passed noise for texture.
      final w = rng.nextDouble() * 2.0 - 1.0;
      _lp = _lp + 0.02 * (w - _lp);

      final rumble = (sine1 * 0.55 + sine2 * 0.35 + _lp * 0.55);
      s += rumble * env * amp * 0.60;
    }

    return s;
  }
}

double _softClip(double x, {double drive = 1.0}) {
  // Gentle tanh-style saturator (cheap polynomial approximation).
  final y = x * drive;
  final a = y.abs();
  if (a <= 1.0) {
    // cubic soft clip
    return y - (y * y * y) / 3.0;
  }
  return y.sign * (2.0 / 3.0);
}

Uint8List _wavFromPcm16Mono(Int16List samples, {required int sampleRate}) {
  const numChannels = 1;
  const bitsPerSample = 16;

  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);

  final dataSize = samples.lengthInBytes;
  final fileSize = 44 - 8 + dataSize;

  final bytes = Uint8List(44 + dataSize);
  final bd = ByteData.sublistView(bytes);

  // RIFF header
  bytes.setRange(0, 4, Uint8List.fromList('RIFF'.codeUnits));
  bd.setUint32(4, fileSize, Endian.little);
  bytes.setRange(8, 12, Uint8List.fromList('WAVE'.codeUnits));

  // fmt chunk
  bytes.setRange(12, 16, Uint8List.fromList('fmt '.codeUnits));
  bd.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  bd.setUint16(20, 1, Endian.little); // audio format = PCM
  bd.setUint16(22, numChannels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, byteRate, Endian.little);
  bd.setUint16(32, blockAlign, Endian.little);
  bd.setUint16(34, bitsPerSample, Endian.little);

  // data chunk
  bytes.setRange(36, 40, Uint8List.fromList('data'.codeUnits));
  bd.setUint32(40, dataSize, Endian.little);

  // PCM payload
  final payload = bytes.buffer.asByteData(44);
  for (var i = 0; i < samples.length; i++) {
    payload.setInt16(i * 2, samples[i], Endian.little);
  }

  return bytes;
}
