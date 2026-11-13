import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';

/// Entered data of a machine with a fixed cycle time.
typedef MachineFields = ({String name, int cycleMicros, bool parallel});

/// Asks for name, cycle time (in [unit]) and whether the machine works in
/// parallel with the last group member. Null if cancelled.
Future<MachineFields?> showMachineDialog(
  BuildContext context,
  TimeUnit unit, {
  bool canBeParallel = true,
}) {
  final l = AppLocalizations.of(context);
  final name = TextEditingController();
  final cycle = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var parallel = false;
  return showDialog<MachineFields>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.addMachine),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.addMachineHint,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                TextFormField(
                  key: const Key('machineNameField'),
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.nameLabel),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? l.nameRequired : null,
                ),
                TextFormField(
                  key: const Key('machineCycleField'),
                  controller: cycle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${l.averageCycleTime} [${inputUnitLabel(unit)}]',
                  ),
                  validator: (v) => parseTimeInput(v ?? '', unit) == null
                      ? l.invalidTime
                      : null,
                ),
                if (canBeParallel)
                  SwitchListTile(
                    key: const Key('machineParallelSwitch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.parallelToPrevious),
                    value: parallel,
                    onChanged: (v) => setState(() => parallel = v),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('saveMachineButton'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, (
                name: name.text.trim(),
                cycleMicros: parseTimeInput(cycle.text, unit)!,
                parallel: parallel,
              ));
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
}

/// Asks for a new cycle time in [unit]; null if cancelled.
Future<int?> showCycleTimeDialog(BuildContext context, TimeUnit unit) {
  final l = AppLocalizations.of(context);
  final cycle = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.setCycleTime),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.setCycleTimeHint, style: Theme.of(ctx).textTheme.bodySmall),
            TextFormField(
              key: const Key('cycleTimeField'),
              controller: cycle,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '${l.averageCycleTime} [${inputUnitLabel(unit)}]',
              ),
              validator: (v) =>
                  parseTimeInput(v ?? '', unit) == null ? l.invalidTime : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          key: const Key('saveCycleTimeButton'),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, parseTimeInput(cycle.text, unit));
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
}
