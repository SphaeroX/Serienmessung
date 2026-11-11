/// Smooth video position between the player's coarse position updates.
///
/// Players report their position only every 100–500 ms. Between reports the
/// position is extrapolated with the monotonic clock and the playback speed.
/// Small deviations at a new report are corrected gradually (no visible
/// jump back); large deviations (seek, stall) snap immediately.
class PositionInterpolator {
  PositionInterpolator({this.tolerance = 150000, this.smoothWindow = 400000});

  /// Deviations up to this size (µs) are blended in instead of snapped.
  final int tolerance;

  /// Time (µs, monotonic) over which a small correction is blended in.
  final int smoothWindow;

  int _reported = 0;
  int _reportedAt = 0;
  bool _playing = false;
  double _speed = 1;
  int _duration = 0;
  int _correction = 0;
  int _correctionAt = 0;
  int _lastShown = 0;

  int _raw(int now) {
    if (!_playing) return _reported;
    final v = _reported + ((now - _reportedAt) * _speed).round();
    return _duration > 0 && v > _duration ? _duration : v;
  }

  /// Position to display at monotonic time [now].
  int estimate(int now) {
    final v = _peek(now);
    _lastShown = v;
    return v;
  }

  /// Like [estimate] without remembering the value.
  int _peek(int now) {
    var v = _raw(now);
    if (_correction != 0) {
      final f = 1 - (now - _correctionAt) / smoothWindow;
      if (f > 0) v += (_correction * f).round();
    }
    // Never run backwards while playing.
    if (_playing && v < _lastShown) v = _lastShown;
    return v;
  }

  /// New position report from the player.
  void report({
    required int position,
    required int now,
    required bool playing,
    required double speed,
    int duration = 0,
  }) {
    // What would be displayed right now with the previous report.
    final shown = _peek(now);
    final wasPlaying = _playing;
    _reported = position;
    _reportedAt = now;
    _playing = playing;
    _speed = speed;
    _duration = duration;
    final error = _raw(now) - shown;
    if (!playing || !wasPlaying || error.abs() > tolerance) {
      snap(position, now);
      return;
    }
    // Keep the display continuous and blend the error in over time.
    _correction = -error;
    _correctionAt = now;
    _lastShown = shown;
  }

  /// Jumps to [position] immediately (seek, pause).
  void snap(int position, int now) {
    _reported = position;
    _reportedAt = now;
    _correction = 0;
    _lastShown = position;
  }
}
