import 'dart:math' as math;
import 'dart:typed_data';

class VoiceActivity {
  const VoiceActivity(this.level, this.hasSpeech, this.shouldFinish);
  final double level;
  final bool hasSpeech, shouldFinish;
}

/// Audio energy endpointing; no sound leaves the device.
class VoiceActivityDetector {
  int _speechSamples = 0, _quietSamples = 0;

  VoiceActivity add(Float32List samples) {
    if (samples.isEmpty) return VoiceActivity(0, _speechSamples >= 4800, false);
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    final rms = math.sqrt(energy / samples.length);
    if (rms >= 0.008) {
      _speechSamples += samples.length;
      _quietSamples = 0;
    } else {
      _quietSamples += samples.length;
    }
    final heard = _speechSamples >= 4800;
    return VoiceActivity(
      (rms * 12).clamp(0, 1),
      heard,
      heard && _quietSamples >= 28800,
    );
  }
}

abstract interface class VoiceActivityInput {
  Stream<VoiceActivity> get activity;
}
