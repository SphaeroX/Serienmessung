/// A machine type of a loader cell: [count] equal machines, each occupied
/// [workMicros] per part (change, equipping and processing – waiting for a
/// loader left out). Null = not measured.
class CellMachine {
  const CellMachine({
    required this.name,
    required this.workMicros,
    this.count = 1,
  });

  final String name;
  final double? workMicros;
  final int count;
}

/// A loader of a cell: its cycle takes [workMicros] (waiting for a machine
/// or for material left out, waiting for another loader on the shared rail
/// included) and handles [partsPerCycle] parts. Null = not measured.
class CellLoader {
  const CellLoader({
    required this.name,
    required this.workMicros,
    this.partsPerCycle = 1,
  });

  final String name;
  final double? workMicros;
  final int partsPerCycle;
}

/// A machine type or a loader within the evaluated cell.
class CellResource {
  const CellResource({
    required this.name,
    required this.isMachine,
    required this.factor,
    required this.workMicros,
    required this.perPart,
    required this.utilization,
    required this.idlePerCycle,
    required this.isBottleneck,
  });

  final String name;
  final bool isMachine;

  /// Number of machines, or parts per cycle of a loader.
  final int factor;

  /// Time of one own cycle without waiting (µs); null = not measured.
  final double? workMicros;

  /// Time per part (µs): [workMicros] / [factor].
  final double? perPart;

  /// Share of the cell cycle time the resource works (0..1); the machines
  /// of a cell share one value.
  final double? utilization;

  /// Waiting time per own cycle at the pace of the cell (µs).
  final double? idlePerCycle;
  final bool isBottleneck;

  bool get measured => workMicros != null;
}

/// Cycle time of a cell with a given number of machines.
class CellOption {
  const CellOption({
    required this.machines,
    required this.cycleTime,
    required this.machinesAreBottleneck,
  });

  final int machines;
  final double cycleTime;
  final bool machinesAreBottleneck;
}

/// A loader cell: machines served in turn by loaders on a shared rail.
///
/// Every loader touches every part, the machines share the parts. So the
/// cell is as fast as its slowest loader or as its machines together:
/// cycle time = max(loader times per part, 1 / Σ(count / machine time)).
class LoaderCell {
  const LoaderCell._({
    required this.resources,
    required this.cycleTime,
    required this.loaderPace,
    required this.machinePace,
    required this.machineTime,
    required this.singleMachineTime,
  });

  factory LoaderCell.of({
    required List<CellMachine> machines,
    required List<CellLoader> loaders,
  }) {
    double? perPart(double? work, int factor) =>
        work == null || work <= 0 || factor < 1 ? null : work / factor;
    final machineTimes = [
      for (final m in machines) perPart(m.workMicros, m.count),
    ];
    final loaderTimes = [
      for (final l in loaders) perPart(l.workMicros, l.partsPerCycle),
    ];
    final rate = machineTimes.fold<double>(
      0,
      (a, t) => t == null ? a : a + 1 / t,
    );
    final measuredLoaders = [for (final t in loaderTimes) ?t];
    final machinePace = rate == 0 ? null : 1 / rate;
    final loaderPace = measuredLoaders.isEmpty
        ? null
        : measuredLoaders.reduce((a, b) => a > b ? a : b);
    final cycle = machinePace == null || loaderPace == null
        ? null
        : (machinePace > loaderPace ? machinePace : loaderPace);
    final machinesPace = cycle != null && machinePace! > loaderPace!;
    final slowestLoader = loaderPace == null
        ? -1
        : loaderTimes.indexOf(loaderPace);

    final measuredMachines = [
      for (var i = 0; i < machines.length; i++)
        if (machineTimes[i] != null) machines[i],
    ];
    final machineCount = measuredMachines.fold<int>(0, (a, m) => a + m.count);
    return LoaderCell._(
      resources: [
        for (var i = 0; i < machines.length; i++)
          _resource(
            name: machines[i].name,
            isMachine: true,
            factor: machines[i].count,
            work: machineTimes[i] == null ? null : machines[i].workMicros,
            perPart: machineTimes[i],
            // The machines share the parts, so they share the utilization.
            utilization: cycle == null ? null : machinePace! / cycle,
            isBottleneck: machinesPace,
          ),
        for (var i = 0; i < loaders.length; i++)
          _resource(
            name: loaders[i].name,
            isMachine: false,
            factor: loaders[i].partsPerCycle,
            work: loaderTimes[i] == null ? null : loaders[i].workMicros,
            perPart: loaderTimes[i],
            utilization: cycle == null || loaderTimes[i] == null
                ? null
                : loaderTimes[i]! / cycle,
            isBottleneck: cycle != null && !machinesPace && i == slowestLoader,
          ),
      ],
      cycleTime: cycle,
      loaderPace: loaderPace,
      machinePace: machinePace,
      machineTime: machineCount == 0
          ? null
          : measuredMachines.fold<double>(
                  0,
                  (a, m) => a + m.workMicros! * m.count,
                ) /
                machineCount,
      singleMachineTime: measuredMachines.length == 1 && machines.length == 1
          ? measuredMachines.single.workMicros
          : null,
    );
  }

  static CellResource _resource({
    required String name,
    required bool isMachine,
    required int factor,
    required double? work,
    required double? perPart,
    required double? utilization,
    required bool isBottleneck,
  }) {
    final known = work != null && utilization != null && utilization > 0;
    return CellResource(
      name: name,
      isMachine: isMachine,
      factor: factor,
      workMicros: work,
      perPart: perPart,
      utilization: known ? utilization : null,
      idlePerCycle: known ? work / utilization - work : null,
      isBottleneck: isBottleneck && work != null,
    );
  }

  /// Machine types first, then the loaders, each in the given order.
  final List<CellResource> resources;

  /// Time per part of the cell (µs); null unless at least one machine and
  /// one loader are measured.
  final double? cycleTime;

  /// Time per part of the slowest loader (µs).
  final double? loaderPace;

  /// Time per part of all machines together (µs).
  final double? machinePace;

  /// Time one part occupies its machine (µs; mean over the machines).
  final double? machineTime;

  /// Time one part occupies a machine when the cell has one machine type
  /// (µs); null for unequal machines. Basis of [options].
  final double? singleMachineTime;

  bool get measured => cycleTime != null;

  /// The machines pace the cell (otherwise the slowest loader does).
  bool get machinesAreBottleneck =>
      measured && resources.any((r) => r.isMachine && r.isBottleneck);

  /// The loader with the longest time per part; it paces the cell once
  /// there are enough machines. Null without a measured loader.
  CellResource? get slowestLoader {
    CellResource? slowest;
    for (final r in resources) {
      if (r.isMachine || r.perPart == null) continue;
      if (slowest == null || r.perPart! > slowest.perPart!) slowest = r;
    }
    return slowest;
  }

  /// The resources that pace the cell.
  List<CellResource> get bottleneck => [
    for (final r in resources)
      if (r.isBottleneck) r,
  ];

  /// Smallest number of machines from which the slowest loader paces the
  /// cell – another machine brings nothing. Null for unequal machines.
  int? get bestMachineCount {
    final machine = singleMachineTime;
    if (!measured || machine == null) return null;
    return (machine / loaderPace!).ceil();
  }

  /// Cycle time of the cell with 1 to [maxMachines] machines; empty for
  /// unequal machines or a cell that is not measured.
  List<CellOption> options({int maxMachines = 6}) {
    final machine = singleMachineTime;
    if (!measured || machine == null) return const [];
    return [
      for (var n = 1; n <= maxMachines; n++)
        CellOption(
          machines: n,
          cycleTime: machine / n > loaderPace! ? machine / n : loaderPace!,
          machinesAreBottleneck: machine / n > loaderPace!,
        ),
    ];
  }
}
