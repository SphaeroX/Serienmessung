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

/// Entered buffer data; [remove] when the user removes the buffer.
typedef BufferFields = ({
  int capacity,
  int storeMicros,
  int retrieveMicros,
  bool remove,
});

/// Asks for the places and the store/retrieve times (in [unit]) of a buffer.
/// With [existing] values the dialog edits and offers removing it.
Future<BufferFields?> showBufferDialog(
  BuildContext context,
  TimeUnit unit, {
  ({int capacity, int storeMicros, int retrieveMicros})? existing,
}) {
  final l = AppLocalizations.of(context);
  String time(int micros) => formatNumber(
    unit.fromMicros(micros),
    unit == TimeUnit.hm ? 2 : 3,
  ).replaceFirst(RegExp(r'\.?0+$'), '');
  final capacity = TextEditingController(
    text: existing == null ? '' : '${existing.capacity}',
  );
  final store = TextEditingController(
    text: existing == null ? '' : time(existing.storeMicros),
  );
  final retrieve = TextEditingController(
    text: existing == null ? '' : time(existing.retrieveMicros),
  );
  final formKey = GlobalKey<FormState>();
  String? timeError(String? v) =>
      parseTimeInput(v ?? '', unit) == null ? l.invalidTime : null;
  final label = inputUnitLabel(unit);
  return showDialog<BufferFields>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? l.addBuffer : l.editBuffer),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.bufferHint, style: Theme.of(ctx).textTheme.bodySmall),
              TextFormField(
                key: const Key('bufferCapacityField'),
                controller: capacity,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.bufferCapacity),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n == null || n <= 0 ? l.invalidCount : null;
                },
              ),
              TextFormField(
                key: const Key('bufferStoreField'),
                controller: store,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '${l.bufferStoreTime} [$label]',
                ),
                validator: timeError,
              ),
              TextFormField(
                key: const Key('bufferRetrieveField'),
                controller: retrieve,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '${l.bufferRetrieveTime} [$label]',
                ),
                validator: timeError,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            key: const Key('removeBufferButton'),
            onPressed: () => Navigator.pop(ctx, (
              capacity: 0,
              storeMicros: 0,
              retrieveMicros: 0,
              remove: true,
            )),
            child: Text(l.removeBuffer),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          key: const Key('saveBufferButton'),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, (
              capacity: int.parse(capacity.text.trim()),
              storeMicros: parseTimeInput(store.text, unit)!,
              retrieveMicros: parseTimeInput(retrieve.text, unit)!,
              remove: false,
            ));
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
}
