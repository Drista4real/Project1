import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'pcm_audio.dart';
import 'voice_input.dart';
import 'voice_activity.dart';
import 'voice_input_stub.dart' show UnsupportedVoiceInput;

VoiceInput createVoiceInput() =>
    Platform.isAndroid ? OfflineVoiceInput() : UnsupportedVoiceInput();

class OfflineVoiceInput implements VoiceInput, VoiceActivityInput {
  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _audio;
  Completer<void>? _audioDone;
  Isolate? _worker;
  SendPort? _commands;
  Future<void>? _initializing;
  bool _disposed = false;
  bool _recording = false;
  bool _audioError = false;
  int _generation = 0;
  final _activity = StreamController<VoiceActivity>.broadcast();
  VoiceActivityDetector _detector = VoiceActivityDetector();

  @override
  Stream<VoiceActivity> get activity => _activity.stream;

  @override
  bool get supported => true;

  Future<void> _initialize() async {
    if (_commands != null) return;
    if (_initializing != null) return _initializing;
    final loading = _loadWorker();
    _initializing = loading;
    try {
      await loading;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _loadWorker() async {
    final paths = await _installBundledModel();
    if (_disposed) return;
    final ready = ReceivePort();
    try {
      _worker = await Isolate.spawn(_recognizerWorker, [ready.sendPort, paths]);
      final response = await ready.first.timeout(const Duration(seconds: 60));
      if (response is! SendPort) {
        throw const VoiceInputException(
          'Không thể khởi tạo nhận dạng giọng nói.',
        );
      }
      if (_disposed) {
        response.send('dispose');
      } else {
        _commands = response;
      }
    } catch (_) {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      rethrow;
    } finally {
      ready.close();
    }
  }

  @override
  Future<void> start() async {
    if (_disposed || _recording) return;
    final generation = ++_generation;
    try {
      if (!await _recorder.hasPermission()) {
        throw const VoiceInputException(
          'Cần quyền micro để nhập giọng nói. Hãy cấp quyền trong Cài đặt.',
        );
      }
      await _initialize();
      if (_disposed || generation != _generation) return;
      _pcm.clear();
      _detector = VoiceActivityDetector();
      _audioError = false;
      _audioDone = Completer<void>();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      if (_disposed || generation != _generation) {
        await _recorder.cancel();
        return;
      }
      _recording = true;
      _audio = stream.listen(
        (chunk) {
          if (_pcm.length + chunk.length <= 16000 * 2 * 20) {
            _pcm.add(chunk);
            if (!_activity.isClosed &&
                chunk.isNotEmpty &&
                chunk.length.isEven) {
              _activity.add(_detector.add(pcm16Samples(chunk)));
            }
          }
        },
        onError: (Object _) => _audioError = true,
        onDone: () {
          if (_audioDone?.isCompleted == false) _audioDone!.complete();
        },
      );
    } on VoiceInputException {
      rethrow;
    } catch (_) {
      await cancel();
      throw const VoiceInputException(
        'Không thể bật micro hoặc model offline. Hãy thử lại.',
      );
    }
  }

  @override
  Future<String> stop() async {
    if (!_recording || _disposed) return '';
    _recording = false;
    try {
      await _recorder.stop();
      await _audioDone?.future.timeout(const Duration(seconds: 3));
      await _audio?.cancel();
      _audio = null;
      if (_audioError) {
        throw const VoiceInputException('Thu âm bị gián đoạn. Hãy nói lại.');
      }
      final samples = pcm16Samples(_pcm.takeBytes());
      if (samples.length < 4000 ||
          !samples.any((sample) => sample.abs() > 0.005)) {
        throw const VoiceInputException(
          'Không thu được tiếng nói. Kiểm tra micro; nếu dùng giả lập, bật “Virtual microphone uses host audio input” trong Extended Controls → Microphone.',
        );
      }
      final response = ReceivePort();
      try {
        _commands!.send([response.sendPort, samples]);
        final result = await response.first.timeout(
          const Duration(seconds: 90),
        );
        if (result is! String || result.trim().isEmpty) {
          throw const VoiceInputException(
            'Chưa nhận ra nội dung. Hãy nói lại hoặc nhập chữ.',
          );
        }
        return result.trim();
      } finally {
        response.close();
      }
    } on VoiceInputException {
      rethrow;
    } catch (_) {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      _commands = null;
      throw const VoiceInputException(
        'Không thể phiên âm. Hãy thử lại hoặc nhập chữ.',
      );
    } finally {
      _pcm.clear();
      await _audio?.cancel();
      _audio = null;
    }
  }

  @override
  Future<void> cancel() async {
    ++_generation;
    _recording = false;
    await _recorder.cancel();
    await _audio?.cancel();
    _audio = null;
    _pcm.clear();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await cancel();
    _commands?.send('dispose');
    _commands = null;
    await _recorder.dispose();
    await _activity.close();
  }
}

Future<List<String>> _installBundledModel() async {
  const assets = 'assets/models/phowhisper-tiny';
  try {
    final manifestText = await rootBundle.loadString('$assets/manifest.json');
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    final artifacts = manifest['artifacts'] as Map<String, dynamic>;
    final version = sha256.convert(utf8.encode(manifestText)).toString();
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/phowhisper-$version');
    await directory.create(recursive: true);
    final paths = <String>[];
    for (final name in [
      'encoder.int8.onnx',
      'decoder.int8.onnx',
      'tokens.txt',
    ]) {
      final info = artifacts[name] as Map<String, dynamic>;
      final file = File('${directory.path}/$name');
      final valid =
          await file.exists() &&
          await file.length() == info['bytes'] &&
          (await sha256.bind(file.openRead()).first).toString() ==
              info['sha256'];
      if (!valid) {
        final data = await rootBundle.load('$assets/$name');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsBytes(bytes, flush: true);
        if (await temporary.length() != info['bytes'] ||
            (await sha256.bind(temporary.openRead()).first).toString() !=
                info['sha256']) {
          await temporary.delete();
          throw const VoiceInputException(
            'Model giọng nói không hợp lệ. Hãy cập nhật ứng dụng.',
          );
        }
        await temporary.rename(file.path);
      }
      paths.add(file.path);
    }
    return paths;
  } on VoiceInputException {
    rethrow;
  } catch (_) {
    throw const VoiceInputException(
      'Ứng dụng chưa có model tiếng Việt offline. Hãy dùng bản có PhoWhisper hoặc nhập chữ.',
    );
  }
}

Future<void> _recognizerWorker(List<Object> arguments) async {
  final ready = arguments[0] as SendPort;
  final paths = arguments[1] as List<String>;
  final commands = ReceivePort();
  sherpa.OfflineRecognizer? recognizer;
  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: paths[0],
            decoder: paths[1],
            language: 'vi',
            task: 'transcribe',
          ),
          tokens: paths[2],
          modelType: 'whisper',
          numThreads: 2,
          provider: 'cpu',
        ),
      ),
    );
    ready.send(commands.sendPort);
    await for (final command in commands) {
      if (command == 'dispose') break;
      final request = command as List;
      final reply = request[0] as SendPort;
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: request[1] as Float32List,
          sampleRate: 16000,
        );
        recognizer.decode(stream);
        reply.send(recognizer.getResult(stream).text);
      } catch (_) {
        reply.send(null);
      } finally {
        stream.free();
      }
    }
  } catch (_) {
    ready.send(null);
  } finally {
    recognizer?.free();
    commands.close();
  }
}
