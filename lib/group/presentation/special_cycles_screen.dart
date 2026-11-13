import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/special_cycle.dart';

/// Special cycles and planned stops of one machine (study): "every N parts
/// extra time" and "every X hours a stop".
class SpecialCyclesScreen extends ConsumerStatefulWidget {
  const SpecialCyclesScreen({
    super.key,
    required this.studyId,
    required this.studyName,
  });

  final int studyId;
  final String studyName;

  @override
  ConsumerState<SpecialCyclesScreen> createState() =>
      _SpecialCyclesScreenState();
}

class _SpecialCyclesScreenState extends ConsumerState<SpecialCyclesScreen> {
  List<SpecialCycle>? _cycles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cycles = await ref
        .read(specialCycleRepositoryProvider)
        .list(widget.studyId);
    if (mounted) setState(() => _cycles = cycles);
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final unit = ref.read(settingsProvider).defaultUnit;
    final name = TextEditingController();
    final interval = TextEditingController();
    final duration = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var kind = SpecialCycleKind.parts;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.addSpecialCycle),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('specialCycleNameField'),
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l.specialCycleName,
                      hintText: l.specialCycleNameHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<SpecialCycleKind>(
                    segments: [
                      ButtonSegment(
                        value: SpecialCycleKind.parts,
                        label: Text(l.everyParts, key: const Key('kindParts')),
                      ),
                      ButtonSegment(
                        value: SpecialCycleKind.time,
                        label: Text(l.everyHours, key: const Key('kindTime')),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (v) => setState(() => kind = v.first),
                  ),
                  TextFormField(
                    key: const Key('specialCycleIntervalField'),
                    controller: interval,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: kind == SpecialCycleKind.parts
                          ? l.intervalParts
                          : l.intervalHours,
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim().replaceAll(',', '.');
                      if (kind == SpecialCycleKind.parts) {
                        final n = int.tryParse(text);
                        return n == null || n <= 0 ? l.invalidCount : null;
                      }
                      final h = double.tryParse(text);
                      return h == null || h <= 0 ? l.invalidTime : null;
                    },
                  ),
                  TextFormField(
                    key: const Key('specialCycleDurationField'),
                    controller: duration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: kind == SpecialCycleKind.parts
                          ? '${l.extraTime} [${inputUnitLabel(unit)}]'
                          : '${l.stopDuration} [${inputUnitLabel(unit)}]',
                    ),
                    validator: (v) => parseTimeInput(v ?? '', unit) == null
                        ? l.invalidTime
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('saveSpecialCycleButton'),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final text = interval.text.trim().replaceAll(',', '.');
    await ref
        .read(specialCycleRepositoryProvider)
        .add(
          widget.studyId,
          name: name.text.trim().isEmpty
              ? (kind == SpecialCycleKind.parts ? l.everyParts : l.everyHours)
              : name.text.trim(),
          kind: kind,
          interval: kind == SpecialCycleKind.parts
              ? int.parse(text)
              : (double.parse(text) * 3600 * 1000000).round(),
          durationMicros: parseTimeInput(duration.text, unit)!,
        );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(settingsProvider).defaultUnit;
    final locale = Localizations.localeOf(context).languageCode;
    String t(int micros) => formatTime(micros, unit, locale: locale);
    String hours(int micros) => formatNumber(
      micros / 3600000000,
      micros % 3600000000 == 0 ? 0 : 1,
      locale: locale,
    );
    final cycles = _cycles;
    return Scaffold(
      appBar: AppBar(title: Text('${l.specialCycles} · ${widget.studyName}')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addSpecialCycle'),
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l.addSpecialCycle),
      ),
      body: cycles == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                Text(l.specialCyclesHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                if (cycles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.noSpecialCycles, textAlign: TextAlign.center),
                  ),
                for (final c in cycles)
                  Card(
                    key: Key('specialCycle_${c.id}'),
                    child: ListTile(
                      leading: Icon(
                        c.kind == SpecialCycleKind.parts
                            ? Icons.fact_check_outlined
                            : Icons.build_outlined,
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        c.kind == SpecialCycleKind.parts
                            ? l.specialEveryParts(
                                c.interval,
                                t(c.durationMicros),
                              )
                            : l.specialEveryHours(
                                hours(c.interval),
                                t(c.durationMicros),
                              ),
                      ),
                      trailing: IconButton(
                        key: Key('deleteSpecialCycle_${c.id}'),
                        tooltip: l.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref
                              .read(specialCycleRepositoryProvider)
                              .delete(c.id);
                          await _load();
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
