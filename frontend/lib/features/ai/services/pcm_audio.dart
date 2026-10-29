import 'dart:typed_data';

Float32List pcm16Samples(Uint8List pcm) {
  if (pcm.isEmpty || pcm.length.isOdd) {
    throw const FormatException('PCM16 audio must contain complete samples');
  }
  final data = ByteData.sublistView(pcm);
  return Float32List.fromList([
    for (var i = 0; i < pcm.length; i += 2)
      data.getInt16(i, Endian.little) / 32768.0,
  ]);
}
