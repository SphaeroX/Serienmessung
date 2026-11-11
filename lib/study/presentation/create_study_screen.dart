import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../domain/step_parser.dart';
import '../domain/study.dart';
import 'dictation_button.dart';
import 'mode_texts.dart';

/// Form to create a new study. Pops with the new study id.
class CreateStudyScreen extends ConsumerStatefulWidget {
  const CreateStudyScreen({super.key});

  @override
  ConsumerState<CreateStudyScreen> createState() => _CreateStudyScreenState();
}

class _CreateStudyScreenState extends ConsumerState<CreateStudyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _steps = TextEditingController();
  StudyMode _mode = StudyMode.timeStudy;
  bool _saving = false;
  bool _nameInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      _nameInitialized = true;
      final number = (Random().nextInt(9000) + 1000).toString();
      _name.text = AppLocalizations.of(context).defaultStudyName(number);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(studyRepositoryProvider);
    final id = await repo.createStudy(
      name: _name.text.trim(),
      description: _description.text.trim(),
      mode: _mode,
      steps: _mode.usesSteps ? parseSteps(_steps.text) : const [],
      now: ref.read(wallClockProvider)(),
      cycleTimeMethod: ref.read(settingsProvider).defaultMethod.name,
    );
    ref.invalidate(studyListProvider);
    if (mounted) Navigator.of(context).pop(id);
  }

  void _showInfo(StudyMode mode) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.howItWorks,
              style: Theme.of(ctx).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(ctx).colorScheme.primary),
            ),
            Text(mode.title(l)),
          ],
        ),
        content: Text(mode.info(l)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.gotIt)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final stepCount = parseSteps(_steps.text).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.newStudyTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _create,
            child: Text(l.create),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('studyNameField'),
                controller: _name,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l.nameLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _name.clear(),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.nameRequired : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.descriptionLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.modeSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RadioGroup<StudyMode>(
                groupValue: _mode,
                onChanged: (m) => setState(() => _mode = m!),
                child: Column(
                  children: [
                    for (final mode in [
                      StudyMode.timeStudy,
                      StudyMode.video,
                      StudyMode.simple,
                      StudyMode.stepTimer,
                    ])
                      RadioListTile<StudyMode>(
                        value: mode,
                        contentPadding: EdgeInsets.zero,
                        title: Text(mode.title(l)),
                        subtitle: Text(mode.description(l)),
                        secondary: IconButton(
                          tooltip: l.howItWorks,
                          icon: const Icon(Icons.play_circle_outline),
                          onPressed: () => _showInfo(mode),
                        ),
                      ),
                  ],
                ),
              ),
              if (_mode.usesSteps) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('stepsField'),
                        controller: _steps,
                        minLines: 5,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.stepsLabel,
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                          helperText: l.stepsCount(stepCount),
                        ),
                        validator: (v) => parseSteps(v ?? '').isEmpty
                            ? l.stepsRequired
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DictationButton(
                      controller: _steps,
                      onInserted: () => setState(() {}),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: FilledButton(
                  key: const Key('createStudyButton'),
                  onPressed: _saving ? null : _create,
                  child: Text(l.createStudy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
