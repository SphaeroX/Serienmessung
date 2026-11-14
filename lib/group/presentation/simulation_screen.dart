import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../export/domain/group_report.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/line_simulation.dart';

enum _Horizon { shift, day, custom }

/// Simulation of a group's line over a shift, 24 hours or a free period,
/// optionally with one or more machine failures: parts with and without
/// the failures and with and without the buffers, buffer and station
/// figures.
class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _Run {
  const _Run({
    required this.base,
    required this.failed,
    required this.plainLost,
    required this.failures,
  });

  final SimResult base;
  final SimResult? failed;

  /// Parts lost by the failures if the line had no buffers.
  final int? plainLost;
  final List<SimFailure> failures;

  SimResult get shown => failed ?? base;
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  GroupReportInput? _input;
  LineSimulation? _sim;

  /// Number of every simulated station in the line (stations without
  /// times are not simulated but keep their number).
  List<int> _numbers = const [];
  _Horizon _horizon = _Horizon.shift;
  final _hours = TextEditingController(text: '8');

  /// Failures to simulate; the first row always exists (without a machine
  /// = no failure), more rows are added once it has one.
  final List<_FailureRow> _failures = [];
  _Run? _run;
  String? _error;

  @override
  void initState() {
    super.initState();
    _failures.add(_newRow());
  }

  /// A further failure starts on the machine of the one before it.
  _FailureRow _newRow() =>
      _FailureRow('${ref.read(settingsProvider).failureMinutes}')
        ..machine = _failures.isEmpty ? null : _failures.last.machine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_input == null) _load();
  }

  @override
  void dispose() {
    _hours.dispose();
    for (final f in _failures) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final input = await loadGroupReport(
      ref,
      AppLocalizations.of(context),
      Localizations.localeOf(context).languageCode,
      widget.groupId,
    );
    if (!mounted || input == null) return;
    setState(() {
      _input = input;
      _sim = LineSimulation.fromLine(input.line);
      _numbers = [
        for (final st in input.line.stations)
          if (st.measured) st.position + 1,
      ];
    });
    _simulate();
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  int? get _horizonMicros => switch (_horizon) {
    _Horizon.shift => ref.read(settingsProvider).shiftMinutes * 60 * 1000000,
    _Horizon.day => 24 * 3600 * 1000000,
    _Horizon.custom => switch (_number(_hours.text)) {
      final h? when h > 0 => (h * 3600 * 1000000).round(),
      _ => null,
    },
  };

  void _simulate() {
    final sim = _sim;
    final l = AppLocalizations.of(context);
    if (sim == null) return;
    final h = _horizonMicros;
    if (h == null) {
      setState(() => _error = l.invalidTime);
      return;
    }
    final failures = <SimFailure>[];
    for (final row in _failures) {
      final machine = row.machine;
      if (machine == null) continue;
      final start = row.start.text.trim().isEmpty
          ? h ~/ 4
          : ((_number(row.start.text) ?? -1) * 3600 * 1000000).round();
      final minutes = _number(row.duration.text);
      if (start < 0 || minutes == null || minutes <= 0) {
        setState(() => _error = l.invalidTime);
        return;
      }
      failures.add(
        SimFailure(
          station: machine.$1,
          machine: machine.$2,
          startMicros: start,
          durationMicros: (minutes * 60 * 1000000).round(),
        ),
      );
    }
    final base = sim.run(horizonMicros: h);
    final failed = failures.isEmpty
        ? null
        : sim.run(horizonMicros: h, failures: failures);
    int? plainLost;
    if (failures.isNotEmpty && sim.hasBuffers) {
      final plain = sim.withoutBuffers();
      plainLost =
          plain.run(horizonMicros: h).output -
          plain.run(horizonMicros: h, failures: failures).output;
    }
    setState(() {
      _error = null;
      _run = _Run(
        base: base,
        failed: failed,
        plainLost: plainLost,
        failures: failures,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final input = _input;
    final sim = _sim;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          input == null
              ? l.simulation
              : '${l.simulation} · ${input.group.name}',
        ),
      ),
      body: input == null || sim == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: [
                Text(l.simulationHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Text(l.simulationPeriod, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                SegmentedButton<_Horizon>(
                  segments: [
                    ButtonSegment(
                      value: _Horizon.shift,
                      label: Text(
                        '${l.shift} ${_hoursText(ref.read(settingsProvider).shiftMinutes)}',
                        key: const Key('horizonShift'),
                      ),
                    ),
                    ButtonSegment(
                      value: _Horizon.day,
                      label: const Text('24 h', key: Key('horizon24h')),
                    ),
                    ButtonSegment(
                      value: _Horizon.custom,
                      label: Text(l.custom, key: const Key('horizonCustom')),
                    ),
                  ],
                  selected: {_horizon},
                  onSelectionChanged: (v) => setState(() => _horizon = v.first),
                ),
                if (_horizon == _Horizon.custom)
                  TextField(
                    key: const Key('horizonHoursField'),
                    controller: _hours,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l.hoursLabel),
                  ),
                const SizedBox(height: 16),
                Text(l.simulationFailure, style: theme.textTheme.titleSmall),
                for (var i = 0; i < _failures.length; i++)
                  _failureRow(i, sim, l),
                if (_failures.first.machine != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('addFailure'),
                      onPressed: () => setState(() => _failures.add(_newRow())),
                      icon: const Icon(Icons.add),
                      label: Text(l.addFailure),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('runSimulation'),
                  onPressed: _simulate,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l.runSimulation),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                if (_run != null) ..._results(_run!, sim, input, l, theme),
              ],
            ),
    );
  }

  /// Machine, start and duration of failure [i]; the first row keeps the
  /// plain keys, the others are numbered and can be removed.
  Widget _failureRow(int i, LineSimulation sim, AppLocalizations l) {
    final row = _failures[i];
    final suffix = i == 0 ? '' : '_$i';
    final dropdown = DropdownButton<(int, int)?>(
      key: Key('failureMachine$suffix'),
      isExpanded: true,
      value: row.machine,
      items: [
        // Further failures are removed with their button instead.
        if (i == 0) DropdownMenuItem(value: null, child: Text(l.noFailure)),
        for (var si = 0; si < sim.stations.length; si++)
          for (var mi = 0; mi < sim.stations[si].machines.length; mi++)
            DropdownMenuItem(
              value: (si, mi),
              child: Text(
                '${_numbers[si]}. ${sim.stations[si].machines[mi].name}',
              ),
            ),
      ],
      onChanged: (v) => setState(() {
        row.machine = v;
        // Without a first failure there are no further ones.
        if (i == 0 && v == null) {
          for (final f in _failures.skip(1)) {
            f.dispose();
          }
          _failures.removeRange(1, _failures.length);
        }
      }),
    );
    return Column(
      key: ObjectKey(row),
      children: [
        if (i == 0)
          dropdown
        else
          Row(
            children: [
              Expanded(child: dropdown),
              IconButton(
                key: Key('removeFailure$suffix'),
                tooltip: l.removeFailure,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _failures.removeAt(i).dispose();
                }),
              ),
            ],
          ),
        if (row.machine != null)
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('failureStartField$suffix'),
                  controller: row.start,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.failureStart,
                    hintText: l.failureStartHint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: Key('failureDurationField$suffix'),
                  controller: row.duration,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.failureDurationMinutes,
                  ),
                ),
              ),
            ],
          ),
        if (i < _failures.length - 1) const SizedBox(height: 8),
      ],
    );
  }

  static String _hoursText(int minutes) => minutes % 60 == 0
      ? '${minutes ~/ 60} h'
      : '${(minutes / 60).toStringAsFixed(1)} h';

  List<Widget> _results(
    _Run run,
    LineSimulation sim,
    GroupReportInput input,
    AppLocalizations l,
    ThemeData theme,
  ) {
    final locale = input.locale;
    String pct(double v) => '${formatNumber(v * 100, 1, locale: locale)} %';
    Widget tile(String label, String key, String value, {Color? color}) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              key: Key(key),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
    final failed = run.failed;
    final lost = failed == null ? null : run.base.output - failed.output;
    final tiles = [
      tile(l.simPartsNormal, 'simOutput', '${run.base.output}'),
      if (failed != null) ...[
        tile(l.simPartsFailure, 'simOutputFailure', '${failed.output}'),
        tile(
          l.simLost,
          'simLost',
          '$lost',
          color: lost! > 0 ? theme.colorScheme.error : null,
        ),
        if (run.plainLost != null)
          tile(
            l.simLostWithoutBuffers,
            'simLostWithoutBuffers',
            '${run.plainLost}',
          ),
      ],
    ];
    final shown = run.shown;
    return [
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          children: [
            for (final w in tiles) SizedBox(width: box.maxWidth / 2, child: w),
          ],
        ),
      ),
      if (run.plainLost != null && lost != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l.buffersSave(run.plainLost! - lost),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      for (var si = 0; si < sim.stations.length; si++) ...[
        if (shown.conveyors.length > si && shown.conveyors[si] != null)
          Card(
            key: Key('simConveyor_$si'),
            child: ListTile(
              leading: const Icon(Icons.linear_scale),
              title: Text(
                '${l.conveyorCard(shown.conveyors[si]!.capacity)} · '
                '${_numbers[si]}. ${sim.stations[si].name}',
              ),
              subtitle: Text(l.conveyorMaxLevel(shown.conveyors[si]!.maxLevel)),
            ),
          ),
        if (shown.buffers[si] != null)
          Card(
            key: Key('simBuffer_$si'),
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                '${l.bufferPlaces(shown.buffers[si]!.capacity)} · '
                '${_numbers[si]}. ${sim.stations[si].name}',
              ),
              subtitle: Text(
                [
                  l.bufferMaxLevel(
                    shown.buffers[si]!.maxLevel,
                    shown.buffers[si]!.endLevel,
                  ),
                  l.bufferMoves(
                    shown.buffers[si]!.stores,
                    shown.buffers[si]!.retrieves,
                  ),
                  l.bufferHandling(
                    formatDuration(shown.buffers[si]!.handlingMicros),
                  ),
                ].join('\n'),
              ),
            ),
          ),
      ],
      const SizedBox(height: 12),
      Text(l.lineStations, style: theme.textTheme.titleMedium),
      for (var si = 0; si < sim.stations.length; si++)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            title: Text('${_numbers[si]}. ${sim.stations[si].name}'),
            subtitle: Text(
              [
                l.simUtilization(pct(shown.stations[si].utilization)),
                if (shown.stations[si].blockedMicros > 0)
                  l.simBlocked(
                    formatDuration(shown.stations[si].blockedMicros),
                  ),
                if (shown.stations[si].downMicros > 0)
                  l.simDown(formatDuration(shown.stations[si].downMicros)),
              ].join(' · '),
            ),
          ),
        ),
    ];
  }
}

/// One failure being edited: machine as (station, machine), null = none;
/// start in hours (empty = a quarter of the period), duration in minutes.
class _FailureRow {
  _FailureRow(String minutes) : duration = TextEditingController(text: minutes);

  (int, int)? machine;
  final start = TextEditingController();
  final TextEditingController duration;

  void dispose() {
    start.dispose();
    duration.dispose();
  }
}
