import 'dart:isolate';

import 'line_simulation.dart';

/// Lines with more simulated machines than this run off the UI thread
/// (a plant of 60 stations and 100 machines needed about 0.4 s for 24 h
/// and 24 s for all failure scenarios in a debug test run).
const offThreadMachines = 30;

/// Whether [sim] is large enough to run in a background isolate.
bool runsOffThread(LineSimulation sim) =>
    sim.stations.fold(0, (n, s) => n + s.machines.length) > offThreadMachines;

/// One simulation run of the simulation screen: the line without failures,
/// with [failures] (null without) and the parts the failures would cost
/// without buffers (null without failures or buffers).
typedef SimulationRun = ({SimResult base, SimResult? failed, int? plainLost});

/// Simulates [sim] over [horizonMicros], with and without [failures].
SimulationRun simulateRun(
  LineSimulation sim, {
  required int horizonMicros,
  List<SimFailure> failures = const [],
}) {
  final base = sim.run(horizonMicros: horizonMicros);
  final failed = failures.isEmpty
      ? null
      : sim.run(horizonMicros: horizonMicros, failures: failures);
  int? plainLost;
  if (failures.isNotEmpty && sim.hasBuffers) {
    final plain = sim.withoutBuffers();
    plainLost =
        plain.run(horizonMicros: horizonMicros).output -
        plain.run(horizonMicros: horizonMicros, failures: failures).output;
  }
  return (base: base, failed: failed, plainLost: plainLost);
}

/// [simulateRun] in a background isolate (always; see [runsOffThread] for
/// when it is worth it).
Future<SimulationRun> runSimulation(
  LineSimulation sim, {
  required int horizonMicros,
  List<SimFailure> failures = const [],
}) => Isolate.run(
  () => simulateRun(sim, horizonMicros: horizonMicros, failures: failures),
);

/// [LineSimulation.failureScenarios] in a background isolate for a large
/// line, directly for a small one.
Future<List<FailureScenario>> failureScenariosOf(
  LineSimulation sim, {
  required int horizonMicros,
  required int durationMicros,
  required int startMicros,
}) {
  List<FailureScenario> compute() => sim.failureScenarios(
    horizonMicros: horizonMicros,
    durationMicros: durationMicros,
    startMicros: startMicros,
  );
  return runsOffThread(sim) ? Isolate.run(compute) : Future.value(compute());
}
