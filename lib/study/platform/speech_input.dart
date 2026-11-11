import 'package:speech_to_text/speech_to_text.dart';

/// Push-to-talk speech recognition, behind an interface for tests.
abstract class SpeechInput {
  /// Starts listening. Returns false if recognition is unavailable or the
  /// microphone permission was denied. [onText] receives the text recognized
  /// so far (partial results).
  Future<bool> start({
    required String localeId,
    required void Function(String text) onText,
  });

  /// Stops listening and returns the recognized text.
  Future<String> stop();
}

/// Uses the platform recognizer via `speech_to_text`.
class SystemSpeechInput implements SpeechInput {
  final _speech = SpeechToText();
  bool _ready = false;
  String _last = '';

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onText,
  }) async {
    try {
      // Requests the microphone permission on first use.
      _ready = _ready || await _speech.initialize();
      if (!_ready) return false;
      _last = '';
      await _speech.listen(
        onResult: (r) {
          _last = r.recognizedWords;
          onText(_last);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<String> stop() async {
    try {
      await _speech.stop();
      // The final result may arrive shortly after stopping.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } on Object {
      // Ignore: keep what was recognized so far.
    }
    return _last;
  }
}
