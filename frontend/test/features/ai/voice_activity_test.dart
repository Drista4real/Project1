import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/ai/services/voice_activity.dart';

void main() {
  test('silence alone does not trigger a transcription', () {
    final detector = VoiceActivityDetector();
    final state = detector.add(Float32List(16000 * 20));
    expect(state.hasSpeech, isFalse);
    expect(state.shouldFinish, isFalse);
  });

  test('speech followed by a pause finishes; short pauses do not', () {
    final detector = VoiceActivityDetector();
    final speech = Float32List.fromList(List.filled(8000, 0.03));
    expect(detector.add(speech).hasSpeech, isTrue);
    expect(detector.add(Float32List(16000)).shouldFinish, isFalse);
    expect(detector.add(speech).shouldFinish, isFalse);
    expect(detector.add(Float32List(28800)).shouldFinish, isTrue);
  });
}
