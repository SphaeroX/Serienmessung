import 'line_analysis.dart';
import 'special_cycle.dart';

/// A machine of a simulated station with its (deterministic) cycle time.
class SimMachine {
  const SimMachine({
    required this.name,
    required this.cycleMicros,
    this.specialCycles = const [],
  });

  final String name;

  /// Measured cycle time without special cycles.
  final int cycleMicros;

  /// Every N-th part takes extra time; planned stops come first after half
  /// their interval, then every interval.
  final List<SpecialCycle> specialCycles;
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
    this.conveyorBefore,
  });

  final String name;
  final List<SimMachine> machines;
  final SimBuffer? bufferBefore;

  /// Conveyor from the station before; a buffer at the same place stores
  /// only when the conveyor is full.
  final SimConveyor? conveyorBefore;
}

/// A conveyor between two stations: [capacity] parts can be on it (moving
/// or jammed at its end), a part needs [transportMicros] to its end.
class SimConveyor {
  const SimConveyor({required this.capacity, required this.transportMicros});

  final int capacity;
  final int transportMicros;
}

/// Figures of a conveyor over the simulated time.
class SimConveyorStats {
  const SimConveyorStats({required this.capacity, required this.maxLevel});

  final int capacity;

  /// Most parts on the conveyor at the same time.
  final int maxLevel;
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
    this.conveyors = const [],
  });

  /// Per station: statistics of the conveyor before it (null without one).
  final List<SimConveyorStats?> conveyors;

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
  _Machine(this.cycle, this.specialCycles);

  final int cycle;
  final List<SpecialCycle> specialCycles;

  /// Parts started so far (for the every-N-parts rules).
  int parts = 0;

  /// Time stopped within the horizon (failures and planned stops).
  int down = 0;
  _Phase phase = _Phase.idle;
  int busyUntil = 0;
  int holdSince = 0;
  int downFrom = -1;
  int downUntil = -1;
  int busy = 0;
  int blocked = 0;

  bool isDown(int t) => t >= downFrom && t < downUntil;
}

class _Conveyor {
  _Conveyor(this.spec);

  final SimConveyor spec;

  /// Times at which the parts on the conveyor reach its end, ascending.
  final parts = <int>[];

  /// Places held for parts the buffer is retrieving onto the conveyor.
  int reserved = 0;
  int maxLevel = 0;

  int get level => parts.length + reserved;

  bool get hasRoom => level < spec.capacity;

  void _track() {
    if (level > maxLevel) maxLevel = level;
  }

  void add(int readyAt) {
    var i = parts.length;
    while (i > 0 && parts[i - 1] > readyAt) {
      i--;
    }
    parts.insert(i, readyAt);
    _track();
  }

  void reserve() {
    reserved += 1;
    _track();
  }

  /// A retrieved part placed at the end of the conveyor, ready at [t].
  void place(int t) {
    reserved -= 1;
    add(t);
  }
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
              SimMachine(
                name: m.name,
                cycleMicros: (m.baseCycleTime ?? m.cycleTime!).round(),
                specialCycles: m.specialCycles,
              ),
          ],
          bufferBefore: st.bufferBefore == null
              ? null
              : SimBuffer(
                  capacity: st.bufferBefore!.capacity,
                  storeMicros: st.bufferBefore!.storeMicros,
                  retrieveMicros: st.bufferBefore!.retrieveMicros,
                ),
          conveyorBefore: st.conveyorBefore == null
              ? null
              : SimConveyor(
                  capacity: st.conveyorBefore!.capacity,
                  transportMicros: st.conveyorBefore!.transportMicros,
                ),
        ),
  ]);

  final List<SimStation> stations;

  bool get hasBuffers => stations.skip(1).any((s) => s.bufferBefore != null);

  /// The same line without any buffer (conveyors stay).
  LineSimulation withoutBuffers() => LineSimulation([
    for (final s in stations)
      SimStation(
        name: s.name,
        machines: s.machines,
        conveyorBefore: s.conveyorBefore,
      ),
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
        [for (final m in s.machines) _Machine(m.cycleMicros, m.specialCycles)],
    ];
    // Stops of all machines (planned stops and the failure), by start time:
    // (start, duration, station, machine).
    final stops = <(int, int, int, int)>[
      for (var si = 0; si < stations.length; si++)
        for (var mi = 0; mi < stations[si].machines.length; mi++)
          for (final c in stations[si].machines[mi].specialCycles)
            if (c.kind == SpecialCycleKind.time &&
                c.interval > 0 &&
                c.durationMicros > 0)
              for (
                var at = c.interval ~/ 2;
                at <= horizonMicros;
                at += c.interval
              )
                (at, c.durationMicros, si, mi),
      if (failure != null)
        (
          failure.startMicros,
          failure.durationMicros,
          failure.station,
          failure.machine,
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var nextStop = 0;
    final buffers = [
      for (var i = 0; i < stations.length; i++)
        i > 0 && stations[i].bufferBefore != null
            ? _Buffer(stations[i].bufferBefore!)
            : null,
    ];
    final conveyors = [
      for (var i = 0; i < stations.length; i++)
        i > 0 && stations[i].conveyorBefore != null
            ? _Conveyor(stations[i].conveyorBefore!)
            : null,
    ];
    var output = 0;
    final last = stations.length - 1;

    void start(_Machine m, int t) {
      final from = m.isDown(t) ? m.downUntil : t;
      m.parts += 1;
      var time = m.cycle;
      for (final c in m.specialCycles) {
        if (c.kind == SpecialCycleKind.parts &&
            c.interval > 0 &&
            m.parts % c.interval == 0) {
          time += c.durationMicros;
        }
      }
      m.phase = _Phase.busy;
      m.busyUntil = from + time;
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
          final c = conveyors[si];
          if (c != null) {
            // Parts at the end of the conveyor go to free machines.
            while (free.isNotEmpty &&
                c.parts.isNotEmpty &&
                c.parts.first <= t) {
              c.parts.removeAt(0);
              start(free.removeAt(0), t);
              changed = true;
            }
            // Finished parts leave on the conveyor while it has room.
            while (holders.isNotEmpty && c.hasRoom) {
              release(holders.removeAt(0), t);
              c.add(t + c.spec.transportMicros);
              changed = true;
            }
            if (b == null || !b.idle) continue;
            if (holders.isNotEmpty && b.level < b.spec.capacity) {
              // The conveyor is full: store the oldest waiting part.
              release(holders.removeAt(0), t);
              b
                ..storing = true
                ..busyUntil = t + b.spec.storeMicros
                ..stores += 1;
              changed = true;
            } else if (b.level > 0 && c.hasRoom) {
              // Room on the conveyor: put a stored part on it in front of
              // the station.
              c.reserve();
              b
                ..level -= 1
                ..retrieving = true
                ..busyUntil = t + b.spec.retrieveMicros
                ..retrieves += 1;
              changed = true;
            }
            continue;
          }
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
      for (final c in conveyors) {
        if (c == null) continue;
        for (final ready in c.parts) {
          if (ready > now) {
            consider(ready);
            break;
          }
        }
      }
      if (nextStop < stops.length) consider(stops[nextStop].$1);
      if (next == null || next! > h) break;
      final t = next!;
      now = t;

      while (nextStop < stops.length && stops[nextStop].$1 == t) {
        final (_, duration, si, mi) = stops[nextStop++];
        final m = machines[si][mi];
        // A stop during another one only extends it.
        final until = m.isDown(t) ? m.downUntil + duration : t + duration;
        if (!m.isDown(t)) m.downFrom = t;
        m.down += (until < h ? until : h) - (m.downUntil > t ? m.downUntil : t);
        m.downUntil = until;
        if (m.phase == _Phase.busy && m.busyUntil > t) {
          m.busyUntil += duration;
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
      for (var i = 0; i <= last; i++) {
        final b = buffers[i];
        if (b == null || b.idle || b.busyUntil != t) continue;
        if (b.storing) {
          b
            ..storing = false
            ..level += 1;
          if (b.level > b.maxLevel) b.maxLevel = b.level;
        } else {
          b.retrieving = false;
          final c = conveyors[i];
          if (c == null) {
            b.infeed += 1;
          } else {
            c.place(t);
          }
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
    int down(_Machine m) => m.down;

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
      conveyors: [
        for (final c in conveyors)
          c == null
              ? null
              : SimConveyorStats(
                  capacity: c.spec.capacity,
                  maxLevel: c.maxLevel,
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
