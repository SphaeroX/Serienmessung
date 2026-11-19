import 'line_analysis.dart';

/// What happens to the line when one machine fails.
class MachineFailure {
  const MachineFailure({
    required this.station,
    required this.machine,
    required this.outputAfter,
    required this.loss,
  });

  /// The station the machine belongs to.
  final LineStation station;
  final String machine;

  /// Parts per hour of the line while the machine is down.
  final double outputAfter;

  /// Lost share of the output (0..1); 1 = the whole line stops.
  final double loss;

  bool get standstill => outputAfter == 0;
}

/// Failure scenarios of a line: for every measured machine the output of
/// the line while that machine is down. The line runs at the pace of its
/// slowest station; a station keeps the capacity of its remaining parallel
/// machines, and a station without a remaining machine stops the line. A
/// station that waits for its slowest machine needs all of them: each of
/// its machines stops the line.
class FailureRisk {
  const FailureRisk({required this.baseOutput, required this.failures});

  factory FailureRisk.of(LineAnalysis line) {
    final base = line.outputPerHour;
    if (base == null) return const FailureRisk(baseOutput: null, failures: []);
    const hour = 3600 * 1000000;
    // Capacity of every measured station in parts per hour.
    double capacity(Iterable<double> times) =>
        times.fold<double>(0, (a, t) => a + hour / t);
    final stations = [
      for (final s in line.stations)
        if (s.measured) s,
    ];
    // Capacity of an intact station.
    double intact(LineStation st) => st.waitsForSlowest
        ? hour / st.cycleTime!
        : capacity([for (final m in st.measuredMachines) m.cycleTime!]);
    final failures = <MachineFailure>[];
    for (final s in stations) {
      final machines = s.measuredMachines;
      for (var k = 0; k < machines.length; k++) {
        var output = double.infinity;
        for (final other in stations) {
          final left = !identical(other, s)
              ? intact(other)
              : s.waitsForSlowest
              ? 0.0
              : capacity([
                  for (var j = 0; j < machines.length; j++)
                    if (j != k) machines[j].cycleTime!,
                ]);
          if (left < output) output = left;
        }
        // Rounding noise must not turn "no loss" into a tiny loss.
        final loss = ((base - output) / base).clamp(0.0, 1.0);
        failures.add(
          MachineFailure(
            station: s,
            machine: machines[k].name,
            outputAfter: output,
            loss: loss < 1e-9 ? 0 : loss,
          ),
        );
      }
    }
    // Stable sort: biggest loss first, otherwise line order.
    final ordered = [for (var i = 0; i < failures.length; i++) (i, failures[i])]
      ..sort((a, b) {
        final c = b.$2.loss.compareTo(a.$2.loss);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return FailureRisk(
      baseOutput: base,
      failures: [for (final o in ordered) o.$2],
    );
  }

  /// Parts per hour of the intact line; null without measured stations.
  final double? baseOutput;

  /// Scenarios sorted by loss (largest first).
  final List<MachineFailure> failures;

  /// Stations without a spare machine, in the order of [failures]: their
  /// only machine – or, if the station waits for its slowest machine, each
  /// of its machines – stops the whole line when it fails.
  List<LineStation> get singlePoints {
    final stations = <LineStation>[];
    for (final f in failures) {
      final st = f.station;
      if (f.standstill &&
          (st.waitsForSlowest || st.measuredMachines.length == 1) &&
          !stations.any((x) => identical(x, st))) {
        stations.add(st);
      }
    }
    return stations;
  }
}
