import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Deepgram real-time streaming transcription.
/// Connects via WebSocket and streams PCM16 audio from the microphone.
/// Supported Deepgram language codes for transcription.
/// See https://developers.deepgram.com/docs/language
class DeepgramLanguage {
  const DeepgramLanguage(this.code, this.displayName);
  final String code;
  final String displayName;
  static const en = DeepgramLanguage('en', 'English');
  static const es = DeepgramLanguage('es', 'Spanish');
  static const fr = DeepgramLanguage('fr', 'French');
  static const de = DeepgramLanguage('de', 'German');
  static const it = DeepgramLanguage('it', 'Italian');
  static const pt = DeepgramLanguage('pt', 'Portuguese');
  static const hi = DeepgramLanguage('hi', 'Hindi');
  static const multi = DeepgramLanguage('multi', 'Multilingual (auto-detect)');
  static const List<DeepgramLanguage> values = [en, es, fr, de, it, pt, hi, multi];
}

class DeepgramStreamingService {
  DeepgramStreamingService({
    required this.apiKey,
    this.onTranscript,
    this.language = DeepgramLanguage.en,
  });

  /// API key for Deepgram.
  final String apiKey;

  /// Called when transcript is received. Runs on main isolate for direct UI updates.
  final void Function(String text, bool isFinal)? onTranscript;

  /// Language for transcription. Use [DeepgramLanguage.multi] for auto-detect.
  final DeepgramLanguage language;

  static const int _sampleRate = 16000;

  AudioRecorder? _recorder;
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _recordingSubscription;
  StreamSubscription<dynamic>? _wsSubscription;
  Timer? _keepAliveTimer;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  final _partialController = StreamController<String>.broadcast();
  Stream<String> get partialStream => _partialController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Starts recording and streaming to Deepgram.
  /// Call [stop] when done.
  Future<void> start() async {
    if (_isRecording) return;

    // Multilingual requires nova-2 or nova-3; nova-3 supports more languages (es, fr, de, hi, ru, pt, ja, it, nl)
    // nova-2 multi only supports English + Spanish
    final isMulti = language.code == 'multi';
    final endpointing = isMulti ? 100 : 300;
    final modelParam = isMulti ? '&model=nova-3' : '';
    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=$_sampleRate'
      '&language=${language.code}$modelParam'
      '&interim_results=true&punctuate=true&smart_format=true'
      '&utterance_end_ms=1000&endpointing=$endpointing',
    );
    // Sec-WebSocket-Protocol: token, API_KEY for auth when custom headers not supported
    _channel = WebSocketChannel.connect(
      uri,
      protocols: ['token', apiKey],
    );

    _recorder = AudioRecorder();
    final audioStream = await _recorder!.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _recordingSubscription = audioStream.listen(
      (data) {
        if (data.isNotEmpty) {
          _channel?.sink.add(data);
        }
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Deepgram audio stream error: $e');
      },
    );

    _listenToWebSocket();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'KeepAlive'}));
      } catch (_) {}
    });
    _isRecording = true;
  }

  void _listenToWebSocket() {
    _wsSubscription = _channel!.stream.listen(
      (message) {
        try {
          final String raw;
          if (message is String) {
            raw = message;
          } else if (message is Uint8List || message is List<int>) {
            raw = utf8.decode(message is Uint8List ? message : Uint8List.fromList(message));
          } else {
            return;
          }

          final json = jsonDecode(raw) as Map<String, dynamic>;
          final type = (json['type'] as String? ?? '').toLowerCase();

          // Only process Results messages
          if (type != 'results') return;

          final transcript = _extractTranscript(json);

          if (transcript.trim().isEmpty) return;

          final isFinal = json['is_final'] as bool? ?? false;
          final speechFinal = json['speech_final'] as bool? ?? false;
          final isStable = isFinal || speechFinal;

          // Emit via callback only - streams are for optional listeners; callback handles UI
          onTranscript?.call(transcript, isStable);
          if (isStable) {
            _transcriptController.add(transcript);
          } else {
            _partialController.add(transcript);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Deepgram parse error: $e');
        }
      },
      onError: (e) => _transcriptController.addError(e),
      onDone: () {},
      cancelOnError: false,
    );
  }

  String _extractTranscript(Map<String, dynamic> json) {
    // Standard: channel.alternatives[0].transcript
    var channel = json['channel'] ?? json['Channel'];
    if (channel is Map<String, dynamic>) {
      final alts = (channel['alternatives'] ?? channel['Alternatives']) as List<dynamic>?;
      if (alts != null && alts.isNotEmpty) {
        final first = alts[0] as Map<String, dynamic>?;
        final t = (first?['transcript'] ?? first?['Transcript']) as String?;
        if (t != null && t.isNotEmpty) return t;
      }
    }
    // Fallback: channels[0].alternatives[0].transcript
    final channels = json['channels'] as List<dynamic>?;
    if (channels != null && channels.isNotEmpty) {
      final ch = channels[0] as Map<String, dynamic>?;
      final alts = ch?['alternatives'] as List<dynamic>?;
      if (alts != null && alts.isNotEmpty) {
        final t = (alts[0] as Map<String, dynamic>)['transcript'] as String?;
        if (t != null && t.isNotEmpty) return t;
      }
    }
    // Recursive search for 'transcript' key
    return _findTranscriptInValue(json) ?? '';
  }

  String? _findTranscriptInValue(dynamic v) {
    if (v is Map<String, dynamic>) {
      for (final e in v.entries) {
        if (e.key.toLowerCase() == 'transcript' && e.value is String) {
          final s = e.value as String;
          if (s.isNotEmpty) return s;
        }
        final found = _findTranscriptInValue(e.value);
        if (found != null && found.isNotEmpty) return found;
      }
    } else if (v is List) {
      for (final item in v) {
        final found = _findTranscriptInValue(item);
        if (found != null && found.isNotEmpty) return found;
      }
    }
    return null;
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Stops recording and closes the WebSocket.
  Future<void> stop() async {
    if (!_isRecording) return;

    _stopKeepAlive();
    _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
    await _channel?.sink.close();
    await _wsSubscription?.cancel();

    await _recorder?.stop();
    await _recordingSubscription?.cancel();
    await _recorder?.dispose();
    _channel = null;
    _recorder = null;
    _recordingSubscription = null;
    _wsSubscription = null;
    _isRecording = false;
  }

  void dispose() {
    _transcriptController.close();
    _partialController.close();
  }
}
