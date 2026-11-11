import 'package:cyclescope/recording/domain/key_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

const ms = 1000;

/// Timer factory that only fires when [fire] is called.
class ManualTimers {
  final pending = <void Function()>[];

  CancelTimer start(Duration d, void Function() cb) {
    pending.add(cb);
    return () => pending.remove(cb);
  }

  void fireAll() {
    final list = [...pending];
    pending.clear();
    for (final cb in list) {
      cb();
    }
  }
}

void main() {
  late ManualTimers timers;
  late List<String> calls;
  late KeyInterpreter k;

  KeyInterpreter build({bool withSpecial = true}) => KeyInterpreter(
    holdThreshold: const Duration(milliseconds: 400),
    startTimer: timers.start,
    onNext: (at) => calls.add('next@$at'),
    onStartStop: (at) => calls.add('startStop@$at'),
    onSpecialStart: withSpecial ? (at) => calls.add('specialStart@$at') : null,
    onSpecialEnd: withSpecial ? (at) => calls.add('specialEnd@$at') : null,
  );

  setUp(() {
    timers = ManualTimers();
    calls = [];
    k = build();
  });

  KeyEventData ev(VolumeKey key, bool down, int at) =>
      KeyEventData(key: key, down: down, atMicros: at);

  test('short press volume up triggers exactly one next at key-down time', () {
    k.handle(ev(VolumeKey.up, true, 1000 * ms));
    k.handle(ev(VolumeKey.up, false, 1100 * ms));
    expect(calls, ['next@${1000 * ms}']);
  });

  test('volume down toggles start/stop on key down only', () {
    k.handle(ev(VolumeKey.down, true, 5 * ms));
    k.handle(ev(VolumeKey.down, false, 50 * ms));
    k.handle(ev(VolumeKey.down, true, 900 * ms));
    expect(calls, ['startStop@${5 * ms}', 'startStop@${900 * ms}']);
  });

  test('holding longer than the threshold does not trigger next', () {
    k = build(withSpecial: false);
    k.handle(ev(VolumeKey.up, true, 0));
    timers.fireAll();
    k.handle(ev(VolumeKey.up, false, 2000 * ms));
    expect(calls, isEmpty);
  });

  test('hold starts a special time at key-down and ends it on release', () {
    k.handle(ev(VolumeKey.up, true, 100 * ms));
    timers.fireAll(); // threshold reached while held
    k.handle(ev(VolumeKey.up, false, 3100 * ms));
    expect(calls, ['specialStart@${100 * ms}', 'specialEnd@${3100 * ms}']);
  });

  test('release just below the threshold is a normal next', () {
    k.handle(ev(VolumeKey.up, true, 0));
    k.handle(ev(VolumeKey.up, false, 399 * ms));
    expect(calls, ['next@0']);
    expect(timers.pending, isEmpty);
  });

  test(
    'late release above threshold without timer callback is a special time',
    () {
      k.handle(ev(VolumeKey.up, true, 0));
      k.handle(ev(VolumeKey.up, false, 401 * ms));
      expect(calls, ['specialStart@0', 'specialEnd@${401 * ms}']);
    },
  );

  test('fast repeated presses are all counted', () {
    for (var i = 0; i < 10; i++) {
      k.handle(ev(VolumeKey.up, true, i * 200 * ms));
      k.handle(ev(VolumeKey.up, false, i * 200 * ms + 50 * ms));
    }
    expect(calls.where((c) => c.startsWith('next')).length, 10);
  });

  test('repeated key-down while held is ignored', () {
    k.handle(ev(VolumeKey.up, true, 0));
    k.handle(ev(VolumeKey.up, true, 100 * ms));
    k.handle(ev(VolumeKey.up, false, 150 * ms));
    expect(calls, ['next@0']);
  });
}
