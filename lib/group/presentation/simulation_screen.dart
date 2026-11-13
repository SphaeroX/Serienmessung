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
/// optionally with one machine failing: parts with and without the failure
/// and with and without the buffers, buffer and station figures.
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
    required this.failure,
  });

  final SimResult base;
  final SimResult? failed;

  /// Parts lost by the failure if the line had no buffers.
  final int? plainLost;
  final SimFailure? failure;

  SimResult get shown => failed ?? base;
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  GroupReportInput? _input;
  LineSimulation? _sim;
  _Horizon _horizon = _Horizon.shift;
  final _hours = TextEditingController(text: '8');
  final _start = TextEditingController();
  final _duration = TextEditingController();

  /// Failing machine as (station, machine), null = no failure.
  (int, int)? _machine;
  _Run? _run;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _duration.text = '${s.failureMinutes}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_input == null) _load();
  }

  @override
  void dispose() {
    _hours.dispose();
    _start.dispose();
    _duration.dispose();
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
    SimFailure? failure;
    final machine = _machine;
    if (machine != null) {
      final start = _start.text.trim().isEmpty
          ? h ~/ 4
          : ((_number(_start.text) ?? -1) * 3600 * 1000000).round();
      final minutes = _number(_duration.text);
      if (start < 0 || minutes == null || minutes <= 0) {
        setState(() => _error = l.invalidTime);
        return;
      }
      failure = SimFailure(
        station: machine.$1,
        machine: machine.$2,
        startMicros: start,
        durationMicros: (minutes * 60 * 1000000).round(),
      );
    }
    final base = sim.run(horizonMicros: h);
    final failed = failure == null
        ? null
        : sim.run(horizonMicros: h, failure: failure);
    int? plainLost;
    if (failure != null && sim.hasBuffers) {
      final plain = sim.withoutBuffers();
      plainLost =
          plain.run(horizonMicros: h).output -
          plain.run(horizonMicros: h, failure: failure).output;
    }
    setState(() {
      _error = null;
      _run = _Run(
        base: base,
        failed: failed,
        plainLost: plainLost,
        failure: failure,
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
                DropdownButton<(int, int)?>(
                  key: const Key('failureMachine'),
                  isExpanded: true,
                  value: _machine,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.noFailure)),
                    for (var si = 0; si < sim.stations.length; si++)
                      for (
                        var mi = 0;
                        mi < sim.stations[si].machines.length;
                        mi++
                      )
                        DropdownMenuItem(
                          value: (si, mi),
                          child: Text(
                            '${si + 1}. ${sim.stations[si].machines[mi].name}',
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => _machine = v),
                ),
                if (_machine != null)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('failureStartField'),
                          controller: _start,
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
                          key: const Key('failureDurationField'),
                          controller: _duration,
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
      for (var si = 0; si < sim.stations.length; si++)
        if (shown.buffers[si] != null)
          Card(
            key: Key('simBuffer_$si'),
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                '${l.bufferPlaces(shown.buffers[si]!.capacity)} · '
                '${si + 1}. ${sim.stations[si].name}',
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
      const SizedBox(height: 12),
      Text(l.lineStations, style: theme.textTheme.titleMedium),
      for (var si = 0; si < sim.stations.length; si++)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            title: Text('${si + 1}. ${sim.stations[si].name}'),
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
