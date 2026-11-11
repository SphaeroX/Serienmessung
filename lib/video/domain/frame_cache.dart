/// Converts between video time and frame index for a constant frame rate.
class FrameTiming {
  const FrameTiming({required this.fps, required this.frameCount});

  /// 30 fps assumption when the real frame rate is unknown.
  const FrameTiming.fallback({required int durationMicros})
    : fps = 30,
      frameCount = durationMicros * 30 ~/ 1000000 + 1;

  final double fps;
  final int frameCount;

  int get frameMicros => (1000000 / fps).round();

  /// Index of the frame shown at [micros].
  int indexAt(int micros) => (micros * fps / 1000000).round();

  /// Presentation time of frame [index].
  int timeOf(int index) => (index * 1000000 / fps).round();

  int clampIndex(int index) => index.clamp(0, frameCount - 1);
}

/// Loads decoded frames for [first] and the following [count] frames.
typedef FrameFetch<T> = Future<List<T>> Function(int first, int count);

/// Keeps the decoded frames around the current position, so frame stepping
/// can show the next picture at once instead of waiting for a seek.
///
/// [prefetchAround] loads the missing frames within [radius] of the centre
/// (forward first, the usual stepping direction) in batches of [batch] and
/// drops frames further than `3 * radius` away.
class FrameCache<T> {
  FrameCache({
    required this.frameCount,
    required this.fetch,
    this.radius = 8,
    this.batch = 8,
  });

  final int frameCount;
  final FrameFetch<T> fetch;
  final int radius;
  final int batch;

  final _frames = <int, T>{};
  final _loading = <int>{};
  int _generation = 0;

  T? operator [](int index) => _frames[index];

  void clear() {
    _frames.clear();
    _loading.clear();
    _generation++;
  }

  Future<void> prefetchAround(int center) async {
    if (frameCount <= 0) return;
    final c = center.clamp(0, frameCount - 1);
    _frames.removeWhere((i, _) => (i - c).abs() > 3 * radius);

    bool missing(int i) => !_frames.containsKey(i) && !_loading.contains(i);
    final forward = [
      for (var i = c; i <= c + radius && i < frameCount; i++)
        if (missing(i)) i,
    ];
    final backward = [
      for (var i = c - 1; i >= c - radius && i >= 0; i--)
        if (missing(i)) i,
    ];
    final ranges = [..._ranges(forward), ..._ranges(backward)];
    _loading.addAll(forward);
    _loading.addAll(backward);
    final generation = _generation;
    for (final (first, count) in ranges) {
      try {
        final frames = await fetch(first, count);
        if (generation != _generation) return;
        for (var i = 0; i < frames.length && i < count; i++) {
          _frames[first + i] = frames[i];
        }
      } on Object {
        // Decoder failed: stepping falls back to the player.
      } finally {
        if (generation == _generation) {
          for (var i = first; i < first + count; i++) {
            _loading.remove(i);
          }
        }
      }
    }
  }

  /// Contiguous runs of [indices] (in the given order) as (first, count)
  /// batches, nearest to the centre first.
  List<(int, int)> _ranges(List<int> indices) {
    final runs = <List<int>>[];
    for (final i in indices) {
      final run = runs.isEmpty ? null : runs.last;
      if (run != null && (run.last - i).abs() == 1 && run.length < batch) {
        run.add(i);
      } else {
        runs.add([i]);
      }
    }
    return [
      for (final run in runs) (run.reduce((a, b) => a < b ? a : b), run.length),
    ];
  }
}
