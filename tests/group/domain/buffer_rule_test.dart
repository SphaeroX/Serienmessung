import 'dart:math';

import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
const day = 24 * 3600 * s;

SimStation station(
  String name,
  List<int> seconds, {
  SimBuffer? buffer,
  SimConveyor? conveyor,
}) => SimStation(
  name: name,
  machines: [
    for (var i = 0; i < seconds.length; i++)
      SimMachine(name: '$name ${i + 1}', cycleMicros: seconds[i] * s),
  ],
  bufferBefore: buffer,
  conveyorBefore: conveyor,
);

int output(List<SimStation> line, {int horizon = day, SimFailure? failure}) =>
    LineSimulation(line).run(horizonMicros: horizon, failure: failure).output;

int outputWithoutBuffers(List<SimStation> line, {int horizon = day}) =>
    LineSimulation(line).withoutBuffers().run(horizonMicros: horizon).output;

void main() {
  group('a buffer never slows the line down', () {
    test('station briefly blocked by the bottleneck behind it', () {
      // B waits a few seconds for C in every cycle. Storing a part then
      // takes it away for 40 s although B is free again much sooner.
      final line = [
        station('A', [48, 48]),
        station(
          'B',
          [19],
          buffer: const SimBuffer(
            capacity: 24,
            storeMicros: 22 * s,
            retrieveMicros: 18 * s,
          ),
        ),
        station('C', [25]),
      ];
      expect(output(line), greaterThanOrEqualTo(outputWithoutBuffers(line)));
    });

    test('bottleneck that is free before the part is back from the '
        'buffer', () {
      // B works 41 s; a stored part is back after 24 + 21 s.
      final line = [
        station('A', [62, 62]),
        station(
          'B',
          [41],
          buffer: const SimBuffer(
            capacity: 12,
            storeMicros: 24 * s,
            retrieveMicros: 21 * s,
          ),
        ),
      ];
      expect(output(line), greaterThanOrEqualTo(outputWithoutBuffers(line)));
    });

    test('the buffer still takes parts during a long stop', () {
      final line = [
        station('A', [48, 48]),
        station(
          'B',
          [19],
          buffer: const SimBuffer(
            capacity: 24,
            storeMicros: 22 * s,
            retrieveMicros: 18 * s,
          ),
        ),
        station('C', [25]),
      ];
      final r = LineSimulation(line).run(
        horizonMicros: day,
        failure: const SimFailure(
          station: 1,
          machine: 0,
          startMicros: 3600 * s,
          durationMicros: 1800 * s,
        ),
      );
      expect(r.buffers[1]!.stores, greaterThan(10));
    });

    test('random lines: at most a few parts less than without buffers', () {
      final rnd = Random(30);
      for (var n = 0; n < 300; n++) {
        final line = [
          for (var i = 0; i < 2 + rnd.nextInt(4); i++)
            station(
              'S$i',
              List.filled(1 + rnd.nextInt(3), 5 + rnd.nextInt(120)),
              buffer: rnd.nextInt(2) == 0
                  ? SimBuffer(
                      capacity: 1 + rnd.nextInt(30),
                      storeMicros: rnd.nextInt(30) * s,
                      retrieveMicros: rnd.nextInt(30) * s,
                    )
                  : null,
              conveyor: rnd.nextInt(4) == 0
                  ? SimConveyor(
                      capacity: 1 + rnd.nextInt(10),
                      transportMicros: rnd.nextInt(90) * s,
                    )
                  : null,
            ),
        ];
        final plain = outputWithoutBuffers(line);
        // Parts on their way through a buffer at the end of the period.
        expect(
          output(line),
          greaterThanOrEqualTo(plain - 3 - plain ~/ 200),
          reason: 'line $n',
        );
      }
    });
  });

  group('a buffer at a conveyor', () {
    test('never carries more parts than the conveyor can', () {
      // One part every 60 s fits on the conveyor: 16 parts in 1000 s.
      final line = [
        station('A', [40]),
        station(
          'B',
          [5],
          conveyor: const SimConveyor(capacity: 1, transportMicros: 60 * s),
          buffer: const SimBuffer(
            capacity: 20,
            storeMicros: 2 * s,
            retrieveMicros: 2 * s,
          ),
        ),
      ];
      expect(output(line, horizon: 1000 * s), lessThanOrEqualTo(16));
      expect(
        output(line, horizon: 1000 * s),
        outputWithoutBuffers(line, horizon: 1000 * s),
      );
    });

    test('random lines: the conveyors limit the output', () {
      final rnd = Random(11);
      for (var n = 0; n < 300; n++) {
        final line = [
          for (var i = 0; i < 2 + rnd.nextInt(4); i++)
            station(
              'S$i',
              List.filled(1 + rnd.nextInt(3), 5 + rnd.nextInt(60)),
              buffer: rnd.nextInt(2) == 0
                  ? SimBuffer(
                      capacity: 1 + rnd.nextInt(30),
                      storeMicros: rnd.nextInt(30) * s,
                      retrieveMicros: rnd.nextInt(30) * s,
                    )
                  : null,
              conveyor: rnd.nextInt(2) == 0
                  ? SimConveyor(
                      capacity: 1 + rnd.nextInt(4),
                      transportMicros: (1 + rnd.nextInt(120)) * s,
                    )
                  : null,
            ),
        ];
        var limit = day;
        for (final st in line.skip(1)) {
          final c = st.conveyorBefore;
          if (c == null) continue;
          // Parts that can pass the conveyor, plus those on it at the end.
          final parts = day ~/ c.transportMicros * c.capacity + c.capacity;
          if (parts < limit) limit = parts;
        }
        expect(output(line), lessThanOrEqualTo(limit), reason: 'line $n');
      }
    });
  });
}
