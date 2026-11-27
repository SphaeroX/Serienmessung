import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../domain/step_parser.dart';
import '../domain/study.dart';
import 'mode_texts.dart';

/// The chosen new kind of study and its steps (empty for a simple study).
typedef ChangeModeFields = ({StudyMode mode, List<String> steps});

/// The kinds a study can be turned into; a video study needs an imported
/// video and is created as such.
const changeableModes = [
  StudyMode.simple,
  StudyMode.timeStudy,
  StudyMode.stepTimer,
];

/// Asks for the new kind of a study of [current] kind and, for a kind with
/// steps, its steps (prefilled with [steps]). Warns when the study's
/// [hasTimes] will be deleted. Null if cancelled.
Future<ChangeModeFields?> showChangeModeDialog(
  BuildContext context, {
  required StudyMode current,
  required List<String> steps,
  required bool hasTimes,
}) {
  final l = AppLocalizations.of(context);
  final choices = [
    for (final m in changeableModes)
      if (m != current) m,
  ];
  var mode = choices.first;
  final text = TextEditingController(text: steps.join('\n'));
  final formKey = GlobalKey<FormState>();
  return showDialog<ChangeModeFields>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.changeMode),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.changeModeHint,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                if (hasTimes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.changeModeTimesWarning,
                      key: const Key('changeModeTimesWarning'),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
                RadioGroup<StudyMode>(
                  groupValue: mode,
                  onChanged: (m) => setState(() => mode = m ?? mode),
                  child: Column(
                    children: [
                      for (final m in choices)
                        RadioListTile<StudyMode>(
                          key: Key('changeMode_${m.name}'),
                          contentPadding: EdgeInsets.zero,
                          value: m,
                          secondary: Icon(m.icon),
                          title: Text(m.title(l)),
                        ),
                    ],
                  ),
                ),
                if (mode.usesSteps)
                  TextFormField(
                    key: const Key('changeModeSteps'),
                    controller: text,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(labelText: l.stepsLabel),
                    validator: (v) =>
                        parseSteps(v ?? '').isEmpty ? l.stepsRequired : null,
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
            key: const Key('changeModeConfirm'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, (
                mode: mode,
                steps: mode.usesSteps ? parseSteps(text.text) : <String>[],
              ));
            },
            child: Text(l.changeModeConfirm),
          ),
        ],
      ),
    ),
  );
}
