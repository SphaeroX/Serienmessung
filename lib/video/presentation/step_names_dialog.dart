import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Dialog to name the steps created by markers. Pops with the new names
/// (blank entries keep their old name) or null when cancelled.
///
/// Owns its text controllers and disposes them only when the dialog has
/// left the tree: disposing them right after `showDialog` returns crashes
/// while the dialog is still animating out (focus loss touches them).
class StepNamesDialog extends StatefulWidget {
  const StepNamesDialog({super.key, required this.names});

  final List<String> names;

  @override
  State<StepNamesDialog> createState() => _StepNamesDialogState();
}

class _StepNamesDialogState extends State<StepNamesDialog> {
  late final List<TextEditingController> _fields = [
    for (final n in widget.names) TextEditingController(text: n),
  ];

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, [
      for (var i = 0; i < _fields.length; i++)
        _fields[i].text.trim().isEmpty
            ? widget.names[i]
            : _fields[i].text.trim(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.nameStepsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: Key('stepNameField-$i'),
                  controller: _fields[i],
                  textInputAction: i == _fields.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.stepOf(i + 1, _fields.length),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('saveStepNames'),
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
