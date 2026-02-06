import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/services/white_noise_synth.dart';

void main() {
  test('generateRainWav returns a valid RIFF/WAVE and non-empty PCM data', () {
    final bytes = WhiteNoiseSynth.generateRainWav(seconds: 2, sampleRate: 8000);
    _assertValidWav(bytes, sampleRate: 8000);
  });

  test('generateThunderstormWav returns a valid RIFF/WAVE and non-empty PCM data', () {
    final bytes = WhiteNoiseSynth.generateThunderstormWav(seconds: 2, sampleRate: 8000);
    _assertValidWav(bytes, sampleRate: 8000);
  });
}

void _assertValidWav(Uint8List bytes, {required int sampleRate}) {
  expect(bytes.length, greaterThan(44));

  String s(int offset, int len) {
    return String.fromCharCodes(bytes.sublist(offset, offset + len));
  }

  expect(s(0, 4), 'RIFF');
  expect(s(8, 4), 'WAVE');
  expect(s(12, 4), 'fmt ');
  expect(s(36, 4), 'data');

  final bd = ByteData.sublistView(bytes);
  final fmtSize = bd.getUint32(16, Endian.little);
  expect(fmtSize, 16);

  final audioFormat = bd.getUint16(20, Endian.little);
  expect(audioFormat, 1); // PCM

  final channels = bd.getUint16(22, Endian.little);
  expect(channels, 1);

  final sr = bd.getUint32(24, Endian.little);
  expect(sr, sampleRate);

  final bits = bd.getUint16(34, Endian.little);
  expect(bits, 16);

  final dataSize = bd.getUint32(40, Endian.little);
  expect(dataSize, bytes.length - 44);
  expect(dataSize, greaterThan(0));

  // Ensure it's not silent.
  final pcm = bytes.buffer.asByteData(44);
  int nonZero = 0;
  for (int i = 0; i < dataSize; i += 2) {
    final sample = pcm.getInt16(i, Endian.little);
    if (sample != 0) {
      nonZero++;
      if (nonZero > 100) break;
    }
  }
  expect(nonZero, greaterThan(0));
}
