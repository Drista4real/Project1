import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/ai/services/pcm_audio.dart';

void main() {
  test(
    'PCM16 little-endian preserves signed amplitude for offline recognition',
    () {
      final samples = pcm16Samples(
        Uint8List.fromList([0, 128, 0, 0, 255, 127]),
      );
      expect(samples[0], -1);
      expect(samples[1], 0);
      expect(samples[2], closeTo(32767 / 32768, 0.00001));
    },
  );
  test('empty and truncated audio are rejected', () {
    expect(() => pcm16Samples(Uint8List(0)), throwsFormatException);
    expect(() => pcm16Samples(Uint8List(3)), throwsFormatException);
  });
}
