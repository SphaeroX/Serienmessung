import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../export/domain/group_report.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../domain/failure_risk.dart';
import '../domain/line_analysis.dart';

/// The studies of a group looked at as one line: key figures, a stacked bar
/// chart (yamazumi) of the stations in group order and the station list.
class LineScreen extends ConsumerStatefulWidget {
  const LineScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<LineScreen> createState() => _LineScreenState();
}

class _LineScreenState extends ConsumerState<LineScreen> {
  GroupReportInput? _input;
  LineAnalysis? _line;

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
        title: Text(
          input == null
              ? l.lineAnalysis
              : '${l.lineAnalysis} · ${input.group.name}',
        ),
      ),
      body: input == null || line == null
          ? const Center(child: CircularProgressIndicator())
          : _LineBody(input: input, line: line, l: l, theme: theme),
    );
  }
}

class _LineBody extends StatelessWidget {
  const _LineBody({
    required this.input,
    required this.line,
    required this.l,
    required this.theme,
  });

  final GroupReportInput input;
  final LineAnalysis line;
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
        if (line.measuredCount > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: CustomPaint(
              key: const Key('yamazumiChart'),
              painter: YamazumiPainter(
                line: line,
                colors: _palette(theme),
                axisColor: theme.colorScheme.onSurfaceVariant,
                bottleneckColor: theme.colorScheme.error,
                label: (v) => t(v),
                textStyle: theme.textTheme.labelSmall!,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(l.lineChartHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Text(l.lineStations, style: theme.textTheme.titleMedium),
        for (final st in line.stations)
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
                        if (st.isParallel) ...[
                          l.lineParallelMachines(st.machines.length),
                          for (final m in st.machines)
                            '  ${m.name}: ${m.cycleTime == null ? l.lineNotMeasured : t(m.cycleTime!)}',
                        ],
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
        ..._risk(FailureRisk.of(line), locale),
      ],
    );
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
              '${risk.failures[i].station.position + 1}. ${risk.failures[i].machine}',
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
/// group order, one segment per step, a dashed line at the bottleneck.
class YamazumiPainter extends CustomPainter {
  YamazumiPainter({
    required this.line,
    required this.colors,
    required this.axisColor,
    required this.bottleneckColor,
    required this.label,
    required this.textStyle,
  });

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
    const top = 18.0;
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
        // Number of parallel machines inside the bar.
        final count = text('×${st.machines.length}', color: Colors.white);
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
  bool shouldRepaint(YamazumiPainter old) => old.line != line;
}
