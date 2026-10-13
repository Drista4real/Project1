abstract interface class VoiceInput {
  bool get supported;
  Future<void> start();
  Future<String> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class VoiceInputException implements Exception {
  const VoiceInputException(this.message);
  final String message;
  @override
  String toString() => message;
}
