import 'package:cyclescope/group/domain/loader_cell.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000.0;

/// The cell of the roadmap example: loader 1 = 32 s, loader 2 = 20 s,
/// loader 3 = 15 s per part, a machine is occupied 88 s per part.
LoaderCell example(int machines) => LoaderCell.of(
  machines: [CellMachine(name: 'Machine', workMicros: 88 * s, count: machines)],
  loaders: const [
    CellLoader(name: 'Loader 1', workMicros: 32 * s),
    CellLoader(name: 'Loader 2', workMicros: 20 * s),
    CellLoader(name: 'Loader 3', workMicros: 15 * s),
  ],
);

void main() {
  group('loader cell', () {
    test('cycle time is the slowest loader or the machines sharing the '
        'parts', () {
      expect(example(1).cycleTime, 88 * s);
      expect(example(2).cycleTime, 44 * s);
      expect(example(3).cycleTime, 32 * s);
      expect(example(4).cycleTime, 32 * s);
    });

    test('the bottleneck changes from the machines to the slowest loader', () {
      for (final n in [1, 2]) {
        final cell = example(n);
        expect(cell.machinesAreBottleneck, isTrue);
        expect(cell.bottleneck.map((r) => r.name), ['Machine']);
      }
      for (final n in [3, 4]) {
        final cell = example(n);
        expect(cell.machinesAreBottleneck, isFalse);
        expect(cell.bottleneck.map((r) => r.name), ['Loader 1']);
      }
    });

    test('best machine count is where another machine stops helping', () {
      expect(example(1).bestMachineCount, 3);
      expect(example(4).bestMachineCount, 3);
    });

    test('table of cycle times for 1 to 6 machines', () {
      final options = example(2).options();
      expect(options.map((o) => o.machines), [1, 2, 3, 4, 5, 6]);
      expect(options.map((o) => o.cycleTime), [
        88 * s,
        44 * s,
        32 * s,
        32 * s,
        32 * s,
        32 * s,
      ]);
      expect(options.map((o) => o.machinesAreBottleneck), [
        true,
        true,
        false,
        false,
        false,
        false,
      ]);
    });

    test('utilization and waiting time per own cycle', () {
      final cell = example(3);
      final machine = cell.resources[0];
      final loader1 = cell.resources[1];
      final loader2 = cell.resources[2];
      expect(machine.isMachine, isTrue);
      expect(machine.perPart, closeTo(88 * s / 3, 1));
      expect(machine.utilization, closeTo(88 / 96, 1e-9));
      // Each of the three machines waits 3 × 32 s − 88 s per own cycle.
      expect(machine.idlePerCycle, closeTo(8 * s, 1));
      expect(loader1.isMachine, isFalse);
      expect(loader1.utilization, 1);
      expect(loader1.idlePerCycle, 0);
      expect(loader2.utilization, closeTo(20 / 32, 1e-9));
      expect(loader2.idlePerCycle, closeTo(12 * s, 1));
    });

    test('a loader handling two parts per cycle counts half', () {
      final cell = LoaderCell.of(
        machines: const [CellMachine(name: 'M', workMicros: 30 * s, count: 2)],
        loaders: const [
          CellLoader(name: 'L1', workMicros: 30 * s),
          CellLoader(name: 'L2', workMicros: 62 * s, partsPerCycle: 2),
        ],
      );
      expect(cell.resources[2].perPart, 31 * s);
      expect(cell.cycleTime, 31 * s);
      expect(cell.bottleneck.single.name, 'L2');
      // L2 is the bottleneck: no waiting; L1 waits 1 s per part.
      expect(cell.resources[2].idlePerCycle, 0);
      expect(cell.resources[1].idlePerCycle, closeTo(1 * s, 1));
    });

    test('the magazine loader is the bottleneck when it is the slowest', () {
      final cell = LoaderCell.of(
        machines: const [CellMachine(name: 'M', workMicros: 88 * s, count: 4)],
        loaders: const [
          CellLoader(name: 'L1', workMicros: 32 * s),
          CellLoader(name: 'L2', workMicros: 20 * s),
          CellLoader(name: 'L3', workMicros: 40 * s),
        ],
      );
      expect(cell.cycleTime, 40 * s);
      expect(cell.bottleneck.single.name, 'L3');
      expect(cell.bestMachineCount, 3);
    });

    test('a cell without a measured machine or loader is not measured', () {
      final noMachine = LoaderCell.of(
        machines: const [CellMachine(name: 'M', workMicros: null)],
        loaders: const [CellLoader(name: 'L1', workMicros: 32 * s)],
      );
      expect(noMachine.cycleTime, isNull);
      expect(noMachine.bottleneck, isEmpty);
      expect(noMachine.bestMachineCount, isNull);
      expect(noMachine.options(), isEmpty);
      expect(noMachine.resources.map((r) => r.utilization), [null, null]);

      final noLoader = LoaderCell.of(
        machines: const [CellMachine(name: 'M', workMicros: 88 * s)],
        loaders: const [CellLoader(name: 'L1', workMicros: null)],
      );
      expect(noLoader.cycleTime, isNull);
    });

    test('an unmeasured loader next to measured ones is left out', () {
      final cell = LoaderCell.of(
        machines: const [CellMachine(name: 'M', workMicros: 88 * s)],
        loaders: const [
          CellLoader(name: 'L1', workMicros: 32 * s),
          CellLoader(name: 'L2', workMicros: null),
        ],
      );
      expect(cell.cycleTime, 88 * s);
      expect(cell.resources[2].perPart, isNull);
      expect(cell.resources[2].utilization, isNull);
    });

    test('machine time is the time one part occupies a machine', () {
      expect(example(3).machineTime, 88 * s);
      expect(example(3).loaderPace, 32 * s);
    });

    test('unequal machines add their capacities; no machine table', () {
      final cell = LoaderCell.of(
        machines: const [
          CellMachine(name: 'A', workMicros: 60 * s),
          CellMachine(name: 'B', workMicros: 120 * s, count: 2),
        ],
        loaders: const [CellLoader(name: 'L1', workMicros: 10 * s)],
      );
      // 1/60 + 2/120 parts per second = one part every 30 s.
      expect(cell.cycleTime, closeTo(30 * s, 1));
      expect(cell.machinesAreBottleneck, isTrue);
      expect(cell.bottleneck.map((r) => r.name), ['A', 'B']);
      expect(cell.options(), isEmpty);
      expect(cell.bestMachineCount, isNull);
      // Mean time of a part in its machine (three machines: 60, 120, 120 s).
      expect(cell.machineTime, closeTo(100 * s, 1));
    });
  });
}
