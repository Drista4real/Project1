import 'voice_input.dart';

VoiceInput createVoiceInput() => UnsupportedVoiceInput();

class UnsupportedVoiceInput implements VoiceInput {
  @override
  bool get supported => false;
  @override
  Future<void> start() async => throw const VoiceInputException(
    'Nhập giọng nói offline hiện hỗ trợ Android. Bạn có thể nhập văn bản ở đây.',
  );
  @override
  Future<String> stop() async => '';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}
