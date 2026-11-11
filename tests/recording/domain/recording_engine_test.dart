import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';

const s = 1000000; // one second in microseconds

void main() {
  late FakeClock clock;
  late RecordingEngine engine;

  setUp(() {
    clock = FakeClock(100 * s);
    engine = RecordingEngine(clock: clock, sequence: const [11, 12, 13]);
  });

  test('first step active on start', () {
    engine.start(cycle: 1);
    expect(engine.status, EngineStatus.running);
    expect(engine.currentStepId, 11);
    expect(engine.cycle, 1);
    expect(engine.stepIndex, 0);
  });

  test('next closes the current step and wraps into new cycles', () {
    engine.start(cycle: 1);
    final out = <MeasurementDraft>[];
    for (var i = 1; i <= 7; i++) {
      clock.advanceSeconds(i);
      out.addAll(engine.next());
    }
    expect(out.map((m) => (m.cycle, m.stepId)).toList(), [
      (1, 11),
      (1, 12),
      (1, 13),
      (2, 11),
      (2, 12),
      (2, 13),
      (3, 11),
    ]);
    expect(out.map((m) => m.durationMicros).toList(), [
      1 * s,
      2 * s,
      3 * s,
      4 * s,
      5 * s,
      6 * s,
      7 * s,
    ]);
    expect(out.every((m) => m.kind == MeasurementKind.normal), isTrue);
    expect(engine.cycle, 3);
    expect(engine.currentStepId, 12);
  });

  test('duration equals the difference of the clock timestamps', () {
    engine.start(cycle: 1);
    final start = clock.micros;
    clock.advance(const Duration(milliseconds: 1234));
    final m = engine.next().single;
    expect(m.startMicros, start);
    expect(m.endMicros, start + 1234000);
    expect(m.durationMicros, 1234000);
  });

  test('paused time does not count', () {
    engine.start(cycle: 1);
    clock.advanceSeconds(2);
    engine.toggleStartStop(); // pause
    expect(engine.status, EngineStatus.paused);
    clock.advanceSeconds(10);
    expect(engine.currentStepElapsed(), 2 * s);
    engine.toggleStartStop(); // resume
    expect(engine.status, EngineStatus.running);
    clock.advanceSeconds(3);
    final m = engine.next().single;
    expect(m.durationMicros, 5 * s);
    expect(m.stepId, 11);
  });

  test('a study with one step starts a new cycle on every next', () {
    engine = RecordingEngine(clock: clock, sequence: const [5]);
    engine.start(cycle: 4);
    clock.advanceSeconds(1);
    engine.next();
    clock.advanceSeconds(1);
    final m = engine.next().single;
    expect(m.cycle, 5);
    expect(engine.cycle, 6);
  });

  test('next is ignored when not running', () {
    expect(engine.next(), isEmpty);
    engine.start(cycle: 1);
    engine.toggleStartStop();
    expect(engine.next(), isEmpty);
  });

  test('explicit timestamps are used for next', () {
    engine.start(cycle: 1, at: 100 * s);
    clock.advanceSeconds(5);
    final m = engine.next(at: 103 * s).single;
    expect(m.durationMicros, 3 * s);
    expect(engine.currentStepElapsed(), 2 * s);
  });

  test('discard drops the unfinished step and returns to idle', () {
    engine.start(cycle: 1);
    clock.advanceSeconds(2);
    expect(engine.discard(), isEmpty);
    expect(engine.status, EngineStatus.idle);
  });

  test('free order: next with step id switches to that step', () {
    engine = RecordingEngine(
      clock: clock,
      sequence: const [1, 2, 3],
      freeOrder: true,
    );
    engine.start(cycle: 0);
    expect(engine.currentStepId, 1);
    clock.advanceSeconds(2);
    expect(engine.next(stepId: 3).single.stepId, 1);
    clock.advanceSeconds(1);
    final m = engine.next(stepId: 2).single;
    expect((m.stepId, m.cycle, m.durationMicros), (3, 0, 1 * s));
    expect(engine.currentStepId, 2);
  });

  test('snapshot round trip restores the exact state', () {
    engine.start(cycle: 2);
    clock.advanceSeconds(3);
    engine.next();
    clock.advanceSeconds(1);
    engine.toggleStartStop();
    final snap = engine.snapshot();
    final restored = RecordingEngine(
      clock: clock,
      sequence: const [11, 12, 13],
      restore: EngineSnapshot.fromJson(snap.toJson()),
    );
    expect(restored.status, EngineStatus.paused);
    expect(restored.cycle, 2);
    expect(restored.currentStepId, 12);
    expect(restored.currentStepElapsed(), 1 * s);
  });

  test('special time pauses the step and is stored separately', () {
    engine.start(cycle: 1);
    clock.advanceSeconds(1);
    engine.next(); // step 1 done, step 2 running
    clock.advanceSeconds(5);
    engine.beginSpecial();
    expect(engine.status, EngineStatus.special);
    clock.advanceSeconds(3);
    expect(engine.specialElapsed(), 3 * s);
    expect(engine.currentStepElapsed(), 5 * s);
    final special = engine.endSpecial(note: 'jam').single;
    clock.advanceSeconds(2);
    final step = engine.next().single;

    expect(special.kind, MeasurementKind.special);
    expect(
      (special.cycle, special.stepId, special.durationMicros, special.note),
      (1, 12, 3 * s, 'jam'),
    );
    expect((step.stepId, step.durationMicros), (12, 7 * s));
    expect(engine.currentStepId, 13);
  });

  test('special time starts at the given key-down time', () {
    engine.start(cycle: 1);
    clock.advanceSeconds(10);
    engine.beginSpecial(at: clock.micros - 400000);
    clock.advanceSeconds(1);
    final special = engine.endSpecial().single;
    expect(special.durationMicros, 1400000);
    expect(engine.currentStepElapsed(), 10 * s - 400000);
  });

  test('next is ignored while a special time runs', () {
    engine.start(cycle: 1);
    engine.beginSpecial();
    expect(engine.next(), isEmpty);
  });
}
