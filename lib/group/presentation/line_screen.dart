import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../export/domain/group_report.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../domain/area_analysis.dart';
import '../domain/failure_risk.dart';
import '../domain/line_analysis.dart';
import 'loader_cell_card.dart';
import 'simulation_screen.dart';

/// The studies of a group looked at as one line: key figures, a stacked bar
/// chart (yamazumi) of the stations in group order and the station list.
///
/// A plant (a group with areas) is one line through all its areas; the
/// area card lists each direct area on its own and within the plant.
class LineScreen extends ConsumerStatefulWidget {
  const LineScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<LineScreen> createState() => _LineScreenState();
}

class _LineScreenState extends ConsumerState<LineScreen> {
  GroupReportInput? _input;
  LineAnalysis? _line;
  List<AreaFigures> _areas = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_input == null) _load();
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
      _line = input.line;
      _areas = input.areaFigures;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final input = _input;
    final line = _line;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('simulationButton'),
            tooltip: l.simulation,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SimulationScreen(groupId: widget.groupId),
              ),
            ),
          ),
        ],
        title: Text(
          input == null
              ? l.lineAnalysis
              : '${l.lineAnalysis} · ${input.group.name}',
        ),
      ),
      body: input == null || line == null
          ? const Center(child: CircularProgressIndicator())
          : _LineBody(
              input: input,
              line: line,
              areas: _areas,
              l: l,
              theme: theme,
            ),
    );
  }
}

class _LineBody extends StatelessWidget {
  const _LineBody({
    required this.input,
    required this.line,
    required this.areas,
    required this.l,
    required this.theme,
  });

  final GroupReportInput input;
  final LineAnalysis line;
  final List<AreaFigures> areas;
  final AppLocalizations l;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final locale = input.locale;
    final unit = input.unit;
    final decimals = switch (unit) {
      TimeUnit.hm => 1,
      TimeUnit.seconds => 2,
      _ => 0,
    };
    String t(double v) =>
        formatTime(v.round(), unit, decimals: decimals, locale: locale);
    String delta(double? d, double? ratio) => d == null
        ? ''
        : '${formatDelta(d, unit, decimals: decimals, locale: locale)}'
              '${ratio == null ? '' : ' (${formatRatioDelta(ratio, locale: locale)})'}';
    final bottleneck = line.bottleneck;

    Widget figure(String label, String key, String value, {String? sub}) =>
        Card(
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
                  ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );

    final figures = [
      figure(
        l.lineTotalLabel,
        'lineTotal',
        t(line.totalTime),
        sub: line.totalDelta == null
            ? null
            : l.lineVsPrevious(delta(line.totalDelta, line.totalDeltaRatio)),
      ),
      figure(
        l.lineCycleLabel,
        'lineCycleTime',
        line.lineCycleTime == null ? '–' : t(line.lineCycleTime!),
        sub: line.lineCycleDelta == null
            ? null
            : l.lineVsPrevious(delta(line.lineCycleDelta, null)),
      ),
      figure(l.lineLeadLabel, 'lineLead', t(line.leadTime)),
      figure(l.lineBottleneckLabel, 'lineBottleneck', bottleneck?.name ?? '–'),
      figure(
        l.lineBalanceLabel,
        'lineBalance',
        line.balance == null
            ? '–'
            : '${formatNumber(line.balance! * 100, 1, locale: locale)} %',
      ),
      figure(
        l.lineOutputLabel,
        'lineOutput',
        line.outputPerHour == null
            ? '–'
            : formatNumber(line.outputPerHour!, 1, locale: locale),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        LayoutBuilder(
          builder: (context, box) => Wrap(
            children: [
              for (final f in figures)
                SizedBox(width: box.maxWidth / 2, child: f),
            ],
          ),
        ),
        if (areas.isNotEmpty) ..._areaCard(context, t, locale),
        if (line.measuredCount > 0) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              // Bars stay readable with many stations: scroll sideways.
              final width = line.stations.length * YamazumiPainter.minSlot;
              final chart = SizedBox(
                height: 240,
                width: math.max(box.maxWidth, width),
                child: CustomPaint(
                  key: const Key('yamazumiChart'),
                  painter: YamazumiPainter(
                    line: line,
                    colors: _palette(theme),
                    axisColor: theme.colorScheme.onSurfaceVariant,
                    bottleneckColor: theme.colorScheme.error,
                    label: (v) => t(v),
                    textStyle: theme.textTheme.labelSmall!,
                    areas: [
                      for (final a in areas)
                        if (a.firstStation != null)
                          (
                            name: a.area.group.name,
                            first: a.firstStation!,
                            last: a.lastStation!,
                          ),
                    ],
                  ),
                ),
              );
              return width <= box.maxWidth
                  ? chart
                  : SingleChildScrollView(
                      key: const Key('yamazumiScroll'),
                      scrollDirection: Axis.horizontal,
                      child: chart,
                    );
            },
          ),
          const SizedBox(height: 4),
          Text(l.lineChartHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Text(l.lineStations, style: theme.textTheme.titleMedium),
        for (final st in line.stations) ...[
          for (final a in areas)
            if (a.firstStation == st.position)
              Padding(
                key: Key('lineAreaHeading_${a.area.group.id}'),
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.area.group.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (st.conveyorBefore != null)
            Card(
              key: Key('lineConveyor_${st.position}'),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.linear_scale),
                title: Text(l.conveyorCard(st.conveyorBefore!.capacity)),
                subtitle: Text(
                  l.conveyorTransport(
                    t(st.conveyorBefore!.transportMicros.toDouble()),
                  ),
                ),
              ),
            ),
          if (st.bufferBefore != null)
            Card(
              key: Key('lineBuffer_${st.position}'),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(l.bufferPlaces(st.bufferBefore!.capacity)),
                subtitle: Text(
                  l.bufferTimes(
                    t(st.bufferBefore!.storeMicros.toDouble()),
                    t(st.bufferBefore!.retrieveMicros.toDouble()),
                  ),
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: st.isBottleneck
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.error, width: 2),
                  )
                : null,
            child: ListTile(
              title: Text(
                '${st.position + 1}. ${st.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                st.cycleTime == null
                    ? l.lineNotMeasured
                    : [
                        l.lineShare(
                          '${formatNumber(st.share * 100, 1, locale: locale)} %',
                        ),
                        if (st.isCell) l.loaderCell,
                        if (st.isParallel) ...[
                          st.waitsForSlowest
                              ? l.lineWaitingMachines(st.machines.length)
                              : l.lineParallelMachines(st.machines.length),
                          for (final m in st.machines)
                            '  ${m.name}: ${m.cycleTime == null ? l.lineNotMeasured : t(m.cycleTime!)}',
                        ],
                        for (final m in st.machines)
                          if (m.specialCycles.isNotEmpty &&
                              m.baseCycleTime != null)
                            l.lineSpecialIncluded(m.name, t(m.baseCycleTime!)),
                        if (st.isBottleneck)
                          l.lineBottleneckLabel
                        else
                          l.lineWaiting(t(st.idle!)),
                        if (st.previousCycleTime != null)
                          l.lineVsPrevious(
                            delta(
                              st.cycleTime! - st.previousCycleTime!,
                              st.previousCycleTime == 0
                                  ? null
                                  : (st.cycleTime! - st.previousCycleTime!) /
                                        st.previousCycleTime!,
                            ),
                          ),
                      ].join('\n'),
              ),
              trailing: st.cycleTime == null
                  ? null
                  : Text(
                      t(st.cycleTime!),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: st.isBottleneck ? theme.colorScheme.error : null,
                      ),
                    ),
            ),
          ),
          if (st.isCell) LoaderCellCard(station: st, time: t, locale: locale),
        ],
        ..._risk(FailureRisk.of(line), locale),
      ],
    );
  }

  List<Widget> _areaCard(
    BuildContext context,
    String Function(double) t,
    String locale,
  ) => [
    const SizedBox(height: 16),
    Text(l.lineAreas, style: theme.textTheme.titleMedium),
    const SizedBox(height: 4),
    Text(l.lineAreasHint, style: theme.textTheme.bodySmall),
    Card(
      key: const Key('lineAreas'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final a in areas)
            ListTile(
              key: Key('lineArea_${a.area.group.id}'),
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(
                a.area.group.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (a.firstStation == null)
                    l.lineAreaEmpty
                  else if (a.firstStation == a.lastStation)
                    l.lineAreaStation('${a.firstStation! + 1}')
                  else
                    l.lineAreaStations(
                      '${a.firstStation! + 1}',
                      '${a.lastStation! + 1}',
                    ),
                  if (a.outputPerHour != null)
                    l.lineAreaOutput(
                      formatNumber(a.outputPerHour!, 1, locale: locale),
                    ),
                  if (a.isBottleneck)
                    l.lineAreaBottleneck
                  else if (a.waiting != null)
                    l.lineWaiting(t(a.waiting!)),
                ].join('\n'),
              ),
              trailing: Text(
                a.cycleTime == null ? l.lineNotMeasured : t(a.cycleTime!),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: a.isBottleneck ? theme.colorScheme.error : null,
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LineScreen(groupId: a.area.group.id),
                ),
              ),
            ),
        ],
      ),
    ),
  ];

  /// [machine] of the station at [position], with its area in a plant
  /// ("Back · Tester").
  String _withArea(int position, String machine) {
    for (final a in areas) {
      final first = a.firstStation;
      if (first != null && position >= first && position <= a.lastStation!) {
        return l.areaMachine(a.area.group.name, machine);
      }
    }
    return machine;
  }

  List<Widget> _risk(FailureRisk risk, String locale) {
    if (risk.baseOutput == null) return const [];
    final singles = risk.singlePoints.length;
    return [
      const SizedBox(height: 16),
      Text(l.failureRisk, style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(l.failureRiskHint, style: theme.textTheme.bodySmall),
      if (singles > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l.singlePointsOfFailure(singles),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      for (var i = 0; i < risk.failures.length; i++)
        Card(
          key: Key('risk_$i'),
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            title: Text(
              '${risk.failures[i].station.position + 1}. '
              '${_withArea(risk.failures[i].station.position, risk.failures[i].machine)}',
            ),
            subtitle: Text(
              l.outputDuringFailure(
                formatNumber(risk.failures[i].outputAfter, 1, locale: locale),
              ),
            ),
            trailing: Text(
              risk.failures[i].standstill
                  ? l.standstill
                  : risk.failures[i].loss == 0
                  ? l.noLoss
                  : formatRatioDelta(-risk.failures[i].loss, locale: locale),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: risk.failures[i].standstill
                    ? theme.colorScheme.error
                    : risk.failures[i].loss == 0
                    ? Colors.green.shade700
                    : theme.colorScheme.tertiary,
              ),
            ),
          ),
        ),
    ];
  }

  static List<Color> _palette(ThemeData theme) => [
    theme.colorScheme.primary,
    theme.colorScheme.tertiary,
    theme.colorScheme.secondary,
    theme.colorScheme.primary.withValues(alpha: 0.55),
    theme.colorScheme.tertiary.withValues(alpha: 0.55),
    theme.colorScheme.secondary.withValues(alpha: 0.55),
  ];
}

/// Stacked bar chart of the stations (yamazumi): one bar per station in
/// group order, one segment per step, a dashed line at the bottleneck. The
/// [areas] of a plant are separated by dotted lines and named on top.
class YamazumiPainter extends CustomPainter {
  YamazumiPainter({
    required this.line,
    required this.colors,
    required this.axisColor,
    required this.bottleneckColor,
    required this.label,
    required this.textStyle,
    this.areas = const [],
  });

  /// Smallest width per station; a wider line scrolls sideways.
  static const minSlot = 28.0;

  /// Areas as ranges of station positions.
  final List<({String name, int first, int last})> areas;

  final LineAnalysis line;
  final List<Color> colors;
  final Color axisColor;
  final Color bottleneckColor;
  final String Function(double micros) label;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final max = line.lineCycleTime;
    if (max == null || max == 0 || line.stations.isEmpty) return;
    // Area names get their own band above the value labels.
    final top = areas.isEmpty ? 18.0 : 34.0;
    const bottom = 20.0;
    final chartHeight = size.height - top - bottom;
    final n = line.stations.length;
    final slot = size.width / n;
    final barWidth = (slot * 0.6).clamp(8.0, 56.0);
    double y(double micros) => top + chartHeight * (1 - micros / max);

    TextPainter text(String s, {Color? color}) => TextPainter(
      text: TextSpan(
        text: s,
        style: textStyle.copyWith(color: color ?? axisColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: slot);

    for (final st in line.stations) {
      final cx = slot * (st.position + 0.5);
      final left = cx - barWidth / 2;
      var base = 0.0;
      for (var k = 0; k < st.segments.length; k++) {
        final seg = st.segments[k];
        final rect = Rect.fromLTRB(
          left,
          y(base + seg.micros),
          left + barWidth,
          y(base),
        );
        canvas.drawRect(rect, Paint()..color = colors[k % colors.length]);
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
        base += seg.micros;
      }
      if (st.isParallel && st.cycleTime != null) {
        // Number of parallel machines inside the bar; "3→1" when they
        // make parts of one unit and the station waits for the slowest.
        final count = text(
          st.waitsForSlowest
              ? '${st.machines.length}→1'
              : '×${st.machines.length}',
          color: Colors.white,
        );
        final barTop = y(st.cycleTime!);
        if (y(0) - barTop > count.height + 4) {
          count.paint(canvas, Offset(cx - count.width / 2, barTop + 4));
        }
      }
      if (st.isBottleneck && st.cycleTime != null) {
        canvas.drawRect(
          Rect.fromLTRB(left, y(st.cycleTime!), left + barWidth, y(0)),
          Paint()
            ..color = bottleneckColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      final number = text('${st.position + 1}');
      number.paint(
        canvas,
        Offset(cx - number.width / 2, size.height - bottom + 4),
      );
      if (st.cycleTime != null) {
        final value = text(
          label(st.cycleTime!),
          color: st.isBottleneck ? bottleneckColor : null,
        );
        value.paint(
          canvas,
          Offset(cx - value.width / 2, y(st.cycleTime!) - value.height - 1),
        );
      }
    }
    // Areas: a dotted line on each border, the name on top.
    final border = Paint()
      ..color = axisColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final a in areas) {
      for (final x in {slot * a.first, slot * (a.last + 1)}) {
        if (x <= 0 || x >= size.width) continue;
        for (var yy = 0.0; yy < y(0); yy += 6) {
          canvas.drawLine(Offset(x, yy), Offset(x, yy + 3), border);
        }
      }
      final name = TextPainter(
        text: TextSpan(
          text: a.name,
          style: textStyle.copyWith(
            color: axisColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, slot * (a.last - a.first + 1) - 4));
      name.paint(canvas, Offset(slot * a.first + 3, 0));
    }
    // Axis and dashed bottleneck line.
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), axis);
    final dash = Paint()
      ..color = bottleneckColor
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y(max)), Offset(x + 4, y(max)), dash);
    }
  }

  @override
  bool shouldRepaint(YamazumiPainter old) =>
      old.line != line || old.areas != areas;
}
