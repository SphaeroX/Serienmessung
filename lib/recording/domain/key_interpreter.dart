import 'dart:async';

/// The two hardware keys used for recording.
enum VolumeKey { up, down }

/// A raw key transition with the exact time it happened (clock micros).
class KeyEventData {
  const KeyEventData({
    required this.key,
    required this.down,
    required this.atMicros,
  });

  final VolumeKey key;
  final bool down;
  final int atMicros;
}

/// Cancels a timer started by a [StartTimer].
typedef CancelTimer = void Function();

/// Starts a one-shot timer; injectable for tests.
typedef StartTimer = CancelTimer Function(Duration d, void Function() cb);

CancelTimer _realTimer(Duration d, void Function() cb) {
  final t = Timer(d, cb);
  return t.cancel;
}

/// Turns raw volume-key transitions into recording actions.
///
/// * Volume up, short press → [onNext] with the key-down time.
/// * Volume up, held longer than [holdThreshold] → [onSpecialStart] at the
///   key-down time and [onSpecialEnd] at release. Without special callbacks a
///   long press does nothing.
/// * Volume down → [onStartStop] on key down.
class KeyInterpreter {
  KeyInterpreter({
    required this.onNext,
    required this.onStartStop,
    this.onSpecialStart,
    this.onSpecialEnd,
    this.holdThreshold = const Duration(milliseconds: 400),
    StartTimer? startTimer,
  }) : _startTimer = startTimer ?? _realTimer;

  final void Function(int atMicros) onNext;
  final void Function(int atMicros) onStartStop;
  final void Function(int atMicros)? onSpecialStart;
  final void Function(int atMicros)? onSpecialEnd;
  final Duration holdThreshold;
  final StartTimer _startTimer;

  int? _upDownAt;
  bool _holdFired = false;
  CancelTimer? _cancel;

  bool get _specialEnabled => onSpecialStart != null && onSpecialEnd != null;

  void handle(KeyEventData e) {
    switch (e.key) {
      case VolumeKey.down:
        if (e.down) onStartStop(e.atMicros);
      case VolumeKey.up:
        e.down ? _upPressed(e.atMicros) : _upReleased(e.atMicros);
    }
  }

  void _upPressed(int at) {
    if (_upDownAt != null) return; // auto-repeat or duplicate
    _upDownAt = at;
    _holdFired = false;
    _cancel = _startTimer(holdThreshold, () {
      _cancel = null;
      final downAt = _upDownAt;
      if (downAt == null) return;
      _holdFired = true;
      onSpecialStart?.call(downAt);
    });
  }

  void _upReleased(int at) {
    final downAt = _upDownAt;
    if (downAt == null) return;
    _upDownAt = null;
    _cancel?.call();
    _cancel = null;
    if (_holdFired) {
      onSpecialEnd?.call(at);
      return;
    }
    if (at - downAt < holdThreshold.inMicroseconds) {
      onNext(downAt);
    } else if (_specialEnabled) {
      // Held long, but the timer had not fired yet (event latency).
      onSpecialStart!(downAt);
      onSpecialEnd!(at);
    }
  }

  void dispose() {
    _cancel?.call();
    _cancel = null;
  }
}
