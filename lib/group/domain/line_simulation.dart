import 'line_analysis.dart';

/// A machine of a simulated station with its (deterministic) cycle time.
class SimMachine {
  const SimMachine({required this.name, required this.cycleMicros});

  final String name;
  final int cycleMicros;
}

/// A buffer before a station: a machine of its own that stores parts only
/// when the station is busy and retrieves them again when it is free.
class SimBuffer {
  const SimBuffer({
    required this.capacity,
    required this.storeMicros,
    required this.retrieveMicros,
  });

  final int capacity;
  final int storeMicros;
  final int retrieveMicros;
}

/// A station: one or more machines working in parallel.
class SimStation {
  const SimStation({
    required this.name,
    required this.machines,
    this.bufferBefore,
  });

  final String name;
  final List<SimMachine> machines;
  final SimBuffer? bufferBefore;
}

/// Machine [machine] of station [station] stops at [startMicros] for
/// [durationMicros]; a part in work is finished after the repair.
class SimFailure {
  const SimFailure({
    required this.station,
    required this.machine,
    required this.startMicros,
    required this.durationMicros,
  });

  final int station;
  final int machine;
  final int startMicros;
  final int durationMicros;
}

/// Figures of a station over the simulated time (all machines together).
class SimStationStats {
  const SimStationStats({
    required this.machines,
    required this.horizonMicros,
    required this.busyMicros,
    required this.blockedMicros,
    required this.downMicros,
  });

  final int machines;
  final int horizonMicros;

  /// Time spent working on parts.
  final int busyMicros;

  /// Time a finished part could not move on (jam).
  final int blockedMicros;
  final int downMicros;

  /// Share of the available machine time spent working (0..1).
  double get utilization =>
      horizonMicros == 0 ? 0 : busyMicros / (machines * horizonMicros);

  /// Time without a part to work on.
  int get starvedMicros =>
      machines * horizonMicros - busyMicros - blockedMicros - downMicros;
}

/// Figures of a buffer over the simulated time.
class SimBufferStats {
  const SimBufferStats({
    required this.capacity,
    required this.maxLevel,
    required this.endLevel,
    required this.stores,
    required this.retrieves,
    required this.handlingMicros,
  });

  final int capacity;
  final int maxLevel;
  final int endLevel;
  final int stores;
  final int retrieves;

  /// Time the buffer machine spent storing and retrieving.
  final int handlingMicros;
}

class SimResult {
  const SimResult({
    required this.output,
    required this.horizonMicros,
    required this.stations,
    required this.buffers,
  });

  /// Parts finished by the last station within the horizon.
  final int output;
  final int horizonMicros;
  final List<SimStationStats> stations;

  /// Per station: statistics of the buffer before it (null without one).
  final List<SimBufferStats?> buffers;
}

/// Result of one failure scenario: parts lost compared with the same line
/// without the failure, with the buffers and with all buffers removed.
class FailureScenario {
  const FailureScenario({
    required this.station,
    required this.machine,
    required this.lostWithBuffers,
    required this.lostWithoutBuffers,
  });

  final int station;
  final String machine;
  final int lostWithBuffers;
  final int lostWithoutBuffers;

  /// Parts the buffers save in this scenario.
  int get savedByBuffers => lostWithoutBuffers - lostWithBuffers;
}

/// Time until the station [machines] can take a part from the conveyor:
/// the ([queued] + 1)-th machine to become free, counting from [t].
int _waitFor(List<_Machine> machines, int queued, int t) {
  const never = 1 << 62;
  final free = [
    for (final m in machines)
      switch (m.phase) {
        _Phase.idle => m.isDown(t) ? m.downUntil - t : 0,
        _Phase.busy => m.busyUntil - t,
        _Phase.holding => never,
      },
  ]..sort();
  return queued < free.length ? free[queued] : never;
}

enum _Phase { idle, busy, holding }

class _Machine {
  _Machine(this.cycle);

  final int cycle;
  _Phase phase = _Phase.idle;
  int busyUntil = 0;
  int holdSince = 0;
  int downFrom = -1;
  int downUntil = -1;
  int busy = 0;
  int blocked = 0;

  bool isDown(int t) => t >= downFrom && t < downUntil;
}

class _Buffer {
  _Buffer(this.spec);

  final SimBuffer spec;
  int level = 0;
  int maxLevel = 0;
  bool storing = false;
  bool retrieving = false;
  int busyUntil = 0;

  /// Retrieved part waiting in front of the station (0 or 1).
  int infeed = 0;
  int stores = 0;
  int retrieves = 0;

  bool get idle => !storing && !retrieving;
}

/// Deterministic, event-driven simulation of a line: stations in order,
/// unlimited raw parts before the first station, no space between stations
/// without a buffer (a finished part blocks its machine until the next
/// station takes it), the line starts empty.
///
/// A buffer before a station is a machine of its own with one place in
/// front of the station. It stores a waiting part only on a real jam – when
/// the station stays busy longer than storing takes; a part that can move
/// on passes on the conveyor. Otherwise it brings a stored part to the
/// place in front of the station (also while the station works), which the
/// station takes before parts on the conveyor. The buffer handles one part
/// at a time, so it empties itself whenever the station has spare time.
class LineSimulation {
  const LineSimulation(this.stations);

  /// The measured stations of [line] with their buffers.
  factory LineSimulation.fromLine(LineAnalysis line) => LineSimulation([
    for (final st in line.stations)
      if (st.measured)
        SimStation(
          name: st.name,
          machines: [
            for (final m in st.measuredMachines)
              SimMachine(name: m.name, cycleMicros: m.cycleTime!.round()),
          ],
          bufferBefore: st.bufferBefore == null
              ? null
              : SimBuffer(
                  capacity: st.bufferBefore!.capacity,
                  storeMicros: st.bufferBefore!.storeMicros,
                  retrieveMicros: st.bufferBefore!.retrieveMicros,
                ),
        ),
  ]);

  final List<SimStation> stations;

  bool get hasBuffers => stations.skip(1).any((s) => s.bufferBefore != null);

  /// The same line without any buffer.
  LineSimulation withoutBuffers() => LineSimulation([
    for (final s in stations) SimStation(name: s.name, machines: s.machines),
  ]);

  /// For every machine: parts lost when it stops at [startMicros] for
  /// [durationMicros], with the buffers and without them.
  List<FailureScenario> failureScenarios({
    required int horizonMicros,
    required int durationMicros,
    required int startMicros,
  }) {
    final plain = withoutBuffers();
    final base = run(horizonMicros: horizonMicros).output;
    final plainBase = plain.run(horizonMicros: horizonMicros).output;
    return [
      for (var si = 0; si < stations.length; si++)
        for (var mi = 0; mi < stations[si].machines.length; mi++)
          () {
            final failure = SimFailure(
              station: si,
              machine: mi,
              startMicros: startMicros,
              durationMicros: durationMicros,
            );
            return FailureScenario(
              station: si,
              machine: stations[si].machines[mi].name,
              lostWithBuffers:
                  base -
                  run(horizonMicros: horizonMicros, failure: failure).output,
              lostWithoutBuffers:
                  plainBase -
                  plain
                      .run(horizonMicros: horizonMicros, failure: failure)
                      .output,
            );
          }(),
    ];
  }

  SimResult run({required int horizonMicros, SimFailure? failure}) {
    final h = horizonMicros;
    final machines = [
      for (final s in stations)
        [for (final m in s.machines) _Machine(m.cycleMicros)],
    ];
    final buffers = [
      for (var i = 0; i < stations.length; i++)
        i > 0 && stations[i].bufferBefore != null
            ? _Buffer(stations[i].bufferBefore!)
            : null,
    ];
    var output = 0;
    var failureApplied = failure == null;
    final last = stations.length - 1;

    void start(_Machine m, int t) {
      final from = m.isDown(t) ? m.downUntil : t;
      m.phase = _Phase.busy;
      m.busyUntil = from + m.cycle;
      if (from < h) m.busy += (m.busyUntil < h ? m.busyUntil : h) - from;
    }

    void release(_Machine m, int t) {
      m.blocked += t - m.holdSince;
      m.phase = _Phase.idle;
    }

    bool available(_Machine m, int t) => m.phase == _Phase.idle && !m.isDown(t);

    void dispatch(int t) {
      var changed = true;
      while (changed) {
        changed = false;
        for (var si = last; si >= 0; si--) {
          final own = machines[si];
          if (si == 0) {
            for (final m in own) {
              if (available(m, t)) {
                start(m, t);
                changed = true;
              }
            }
            continue;
          }
          final free = [
            for (final m in own)
              if (available(m, t)) m,
          ];
          final holders = [
            for (final m in machines[si - 1])
              if (m.phase == _Phase.holding) m,
          ]..sort((a, b) => a.holdSince.compareTo(b.holdSince));
          final b = buffers[si];
          // A retrieved part waiting in front of the station is older than
          // anything on the conveyor: it goes first.
          while (b != null && b.infeed > 0 && free.isNotEmpty) {
            b.infeed -= 1;
            start(free.removeAt(0), t);
            changed = true;
          }
          // Direct pass on the conveyor.
          while (free.isNotEmpty && holders.isNotEmpty) {
            release(holders.removeAt(0), t);
            start(free.removeAt(0), t);
            changed = true;
          }
          if (b == null || !b.idle) continue;
          if (holders.isNotEmpty &&
              b.level < b.spec.capacity &&
              _waitFor(own, b.infeed, t) > b.spec.storeMicros) {
            // Real jam (the station stays busy longer than storing takes):
            // store the oldest waiting part, its machine is free again.
            release(holders.removeAt(0), t);
            b
              ..storing = true
              ..busyUntil = t + b.spec.storeMicros
              ..stores += 1;
            changed = true;
          } else if (b.level > 0 && b.infeed == 0) {
            // Bring a stored part in front of the station while it works.
            b
              ..level -= 1
              ..retrieving = true
              ..busyUntil = t + b.spec.retrieveMicros
              ..retrieves += 1;
            changed = true;
          }
        }
      }
    }

    dispatch(0);
    var now = 0;
    while (true) {
      int? next;
      void consider(int v) {
        if (next == null || v < next!) next = v;
      }

      for (final row in machines) {
        for (final m in row) {
          if (m.phase == _Phase.busy) consider(m.busyUntil);
          // An idle machine may take work again after its repair.
          if (m.phase == _Phase.idle && m.downUntil > now) {
            consider(m.downUntil);
          }
        }
      }
      for (final b in buffers) {
        if (b != null && !b.idle) consider(b.busyUntil);
      }
      if (!failureApplied) consider(failure!.startMicros);
      if (next == null || next! > h) break;
      final t = next!;
      now = t;

      if (!failureApplied && failure!.startMicros == t) {
        failureApplied = true;
        final m = machines[failure.station][failure.machine];
        m
          ..downFrom = t
          ..downUntil = t + failure.durationMicros;
        if (m.phase == _Phase.busy && m.busyUntil > t) {
          m.busyUntil += failure.durationMicros;
        }
      }
      for (var si = 0; si <= last; si++) {
        for (final m in machines[si]) {
          if (m.phase == _Phase.busy && m.busyUntil == t) {
            if (si == last) {
              output++;
              m.phase = _Phase.idle;
            } else {
              m
                ..phase = _Phase.holding
                ..holdSince = t;
            }
          }
        }
      }
      for (final b in buffers) {
        if (b == null || b.idle || b.busyUntil != t) continue;
        if (b.storing) {
          b
            ..storing = false
            ..level += 1;
          if (b.level > b.maxLevel) b.maxLevel = b.level;
        } else {
          b
            ..retrieving = false
            ..infeed += 1;
        }
      }
      dispatch(t);
    }

    // Close the open intervals at the horizon.
    for (final row in machines) {
      for (final m in row) {
        if (m.phase == _Phase.holding && m.holdSince < h) {
          m.blocked += h - m.holdSince;
        }
      }
    }
    int down(_Machine m) {
      if (m.downFrom < 0 || m.downFrom >= h) return 0;
      return (m.downUntil < h ? m.downUntil : h) - m.downFrom;
    }

    return SimResult(
      output: output,
      horizonMicros: h,
      stations: [
        for (var si = 0; si <= last; si++)
          SimStationStats(
            machines: machines[si].length,
            horizonMicros: h,
            busyMicros: machines[si].fold(0, (a, m) => a + m.busy),
            blockedMicros: machines[si].fold(0, (a, m) => a + m.blocked),
            downMicros: machines[si].fold(0, (a, m) => a + down(m)),
          ),
      ],
      buffers: [
        for (final b in buffers)
          b == null
              ? null
              : SimBufferStats(
                  capacity: b.spec.capacity,
                  maxLevel: b.maxLevel,
                  endLevel: b.level + (b.storing || b.retrieving ? 1 : 0),
                  stores: b.stores,
                  retrieves: b.retrieves,
                  handlingMicros:
                      b.stores * b.spec.storeMicros +
                      b.retrieves * b.spec.retrieveMicros,
                ),
      ],
    );
  }
}
