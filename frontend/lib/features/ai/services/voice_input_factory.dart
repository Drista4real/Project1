import 'voice_input.dart';
import 'voice_input_stub.dart'
    if (dart.library.io) 'voice_input_native.dart'
    as platform;

VoiceInput createVoiceInput() => platform.createVoiceInput();
