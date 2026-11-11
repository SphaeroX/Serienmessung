import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
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
///
/// The Android recognizer stays busy until a session has delivered its final
/// result. [stop] therefore waits for the "done" status (bounded), so the
/// next [start] does not hit a busy recognizer.
class SystemSpeechInput implements SpeechInput {
  final _speech = SpeechToText();
  bool _ready = false;
  String _last = '';
  Completer<void>? _done;

  static const _finalResultTimeout = Duration(seconds: 2);

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) _finishSession();
  }

  void _finishSession() {
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onText,
  }) async {
    try {
      // Requests the microphone permission on first use.
      _ready =
          _ready ||
          await _speech.initialize(
            onStatus: _onStatus,
            onError: (_) => _finishSession(),
          );
      if (!_ready) return false;
      // A previous session that never reported "done" must not block.
      if (_speech.isListening) await _speech.cancel();
      _last = '';
      _done = Completer<void>();
      final options = SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
      void onResult(SpeechRecognitionResult r) {
        _last = r.recognizedWords;
        onText(_last);
      }

      try {
        await _speech.listen(onResult: onResult, listenOptions: options);
      } on ListenFailedException {
        // Recognizer still busy: reset it and try once more.
        await _speech.cancel();
        await _speech.listen(onResult: onResult, listenOptions: options);
      }
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<String> stop() async {
    try {
      await _speech.stop();
      // The final result arrives shortly after stopping.
      await _done?.future.timeout(_finalResultTimeout, onTimeout: () {});
    } on Object {
      // Ignore: keep what was recognized so far.
    }
    _done = null;
    return _last;
  }
}
