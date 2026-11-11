import 'dart:async';

import 'package:cyclescope/video/domain/frame_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frame timing', () {
    test('index and time convert with the frame rate', () {
      const t = FrameTiming(fps: 25, frameCount: 100);
      expect(t.frameMicros, 40000);
      expect(t.indexAt(1000000), 25);
      expect(t.indexAt(1019000), 25);
      expect(t.indexAt(1021000), 26);
      expect(t.timeOf(26), 1040000);
      expect(t.clampIndex(-3), 0);
      expect(t.clampIndex(500), 99);
    });

    test('30 fps fallback keeps the old step size', () {
      const t = FrameTiming.fallback(durationMicros: 60000000);
      expect(t.timeOf(t.indexAt(1000000) + 1), 1000000 + 33333);
    });
  });

  group('frame cache', () {
    late List<(int, int)> calls;
    late FrameCache<int> cache;

    setUp(() {
      calls = [];
      cache = FrameCache<int>(
        frameCount: 100,
        radius: 3,
        batch: 4,
        fetch: (first, count) async {
          calls.add((first, count));
          return [for (var i = 0; i < count; i++) first + i];
        },
      );
    });

    test('prefetch loads the frames around the centre in batches', () async {
      await cache.prefetchAround(10);
      for (var i = 7; i <= 13; i++) {
        expect(cache[i], i);
      }
      expect(cache[6], isNull);
      expect(cache[14], isNull);
      // Forward first (the usual stepping direction), then backward.
      expect(calls, [(10, 4), (7, 3)]);
    });

    test('only missing frames are fetched', () async {
      await cache.prefetchAround(10);
      calls.clear();
      await cache.prefetchAround(11);
      expect(calls, [(14, 1)]);
    });

    test('frames far from the centre are evicted', () async {
      await cache.prefetchAround(10);
      await cache.prefetchAround(40);
      expect(cache[10], isNull);
      expect(cache[40], 40);
    });

    test('the window is clamped to the video', () async {
      await cache.prefetchAround(0);
      expect(calls, [(0, 4)]);
      calls.clear();
      await cache.prefetchAround(99);
      expect(calls, [(99, 1), (96, 3)]);
    });

    test('frames already being fetched are not requested twice', () async {
      final gate = Completer<void>();
      final slow = FrameCache<int>(
        frameCount: 100,
        radius: 1,
        batch: 8,
        fetch: (first, count) async {
          calls.add((first, count));
          await gate.future;
          return [for (var i = 0; i < count; i++) first + i];
        },
      );
      final a = slow.prefetchAround(10);
      final b = slow.prefetchAround(10);
      gate.complete();
      await Future.wait([a, b]);
      expect(calls, [(10, 2), (9, 1)]);
      expect(slow[11], 11);
    });

    test('a failing fetch leaves the cache usable', () async {
      final failing = FrameCache<int>(
        frameCount: 100,
        radius: 1,
        batch: 8,
        fetch: (first, count) async => throw StateError('decoder'),
      );
      await failing.prefetchAround(5);
      expect(failing[5], isNull);
    });

    test('clear drops all frames', () async {
      await cache.prefetchAround(10);
      cache.clear();
      expect(cache[10], isNull);
    });
  });
}
