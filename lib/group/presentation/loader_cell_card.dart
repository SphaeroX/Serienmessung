import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../domain/line_analysis.dart';
import '../domain/loader_cell.dart';

/// Name of a cell resource with its count: "Machine ×3", "Loader (2 parts
/// per cycle)".
String cellResourceName(AppLocalizations l, CellResource r) => r.isMachine
    ? (r.factor == 1 ? r.name : l.cellMachineCount(r.name, r.factor))
    : (r.factor == 1 ? r.name : l.cellLoaderParts(r.name, r.factor));

/// The loader cell of [station]: time per part, utilization and waiting
/// time of every machine and loader, and the cell cycle time for 1 to 6
/// machines.
class LoaderCellCard extends StatelessWidget {
  const LoaderCellCard({
    super.key,
    required this.station,
    required this.time,
    required this.locale,
  });

  final LineStation station;

  /// Formats a time in µs in the unit of the screen.
  final String Function(double micros) time;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cell = station.cell!;
    final pos = station.position;
    final small = theme.textTheme.bodySmall;
    final head = theme.textTheme.labelSmall;
    TextStyle? mark(bool on) => on
        ? small?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          )
        : small;
    Widget cell_(Widget child, {bool right = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    final options = cell.options();
    final best = cell.bestMachineCount;
    final slowest = cell.slowestLoader;
    final machines = cell.resources
        .where((r) => r.isMachine)
        .fold<int>(0, (a, r) => a + r.factor);
    return Card(
      key: Key('lineCell_$pos'),
      margin: const EdgeInsets.fromLTRB(16, 0, 0, 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.loaderCell, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(l.cellHint, style: small),
            const SizedBox(height: 8),
            if (!cell.measured) Text(l.cellNotMeasured, style: mark(true)),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    cell_(Text(l.cellResource, style: head), right: false),
                    cell_(Text(l.cellPerPart, style: head)),
                    cell_(Text(l.cellUtilization, style: head)),
                    cell_(
                      Text(
                        l.cellWaiting,
                        style: head,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                for (final (i, r) in cell.resources.indexed)
                  TableRow(
                    children: [
                      cell_(
                        Text(
                          cellResourceName(l, r),
                          key: Key('cellResource_${pos}_$i'),
                          style: mark(r.isBottleneck),
                        ),
                        right: false,
                      ),
                      cell_(
                        Text(
                          r.perPart == null ? '–' : time(r.perPart!),
                          key: Key('cellPerPart_${pos}_$i'),
                          style: mark(r.isBottleneck),
                        ),
                      ),
                      cell_(
                        Text(
                          r.utilization == null
                              ? '–'
                              : '${formatNumber(r.utilization! * 100, 1, locale: locale)} %',
                          key: Key('cellUtilization_${pos}_$i'),
                          style: small,
                        ),
                      ),
                      cell_(
                        Text(
                          r.idlePerCycle == null ? '–' : time(r.idlePerCycle!),
                          key: Key('cellWaiting_${pos}_$i'),
                          style: small,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.cellOptionsTitle, style: theme.textTheme.labelLarge),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(1.6),
                },
                children: [
                  TableRow(
                    children: [
                      cell_(Text(l.cellMachines, style: head), right: false),
                      cell_(Text(l.cellCycleTime, style: head)),
                      cell_(Text(l.lineBottleneckLabel, style: head)),
                    ],
                  ),
                  for (final o in options)
                    TableRow(
                      decoration: o.machines == machines
                          ? BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                            )
                          : null,
                      children: [
                        cell_(
                          Text(
                            '${o.machines}',
                            style: small?.copyWith(
                              fontWeight: o.machines == best
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                          right: false,
                        ),
                        cell_(
                          Text(
                            time(o.cycleTime),
                            key: Key('cellOption_${pos}_${o.machines}'),
                            style: small?.copyWith(
                              fontWeight: o.machines == best
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ),
                        cell_(
                          Text(
                            o.machinesAreBottleneck
                                ? l.cellMachines
                                : slowest!.name,
                            key: Key(
                              'cellOptionBottleneck_${pos}_${o.machines}',
                            ),
                            style: small,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (best != null && slowest != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.cellBest(best, slowest.name),
                    key: Key('cellBest_$pos'),
                    style: small?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
