import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../domain/study.dart';
import 'dictation_button.dart';

/// Edits name, description and step definitions of a study.
///
/// Steps are changed immediately (rename, reorder, add, delete). Measurements
/// reference steps by id, so reordering never moves recorded times. Only
/// opened while no recording is running.
class EditStudyScreen extends ConsumerStatefulWidget {
  const EditStudyScreen({super.key, required this.studyId});

  final int studyId;

  @override
  ConsumerState<EditStudyScreen> createState() => _EditStudyScreenState();
}

class _EditStudyScreenState extends ConsumerState<EditStudyScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _newStep = TextEditingController();
  Study? _study;
  List<StepDefinition> _steps = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _newStep.dispose();
    super.dispose();
  }

  Future<void> _load({bool fields = true}) async {
    final repo = ref.read(studyRepositoryProvider);
    final study = await repo.getStudy(widget.studyId);
    final steps = await repo.getSteps(widget.studyId);
    if (!mounted) return;
    setState(() {
      _study = study;
      _steps = steps;
      if (fields && study != null) {
        _name.text = study.name;
        _description.text = study.description;
      }
    });
  }

  Future<void> _saveStudy() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.nameRequired)));
      return;
    }
    await ref
        .read(studyRepositoryProvider)
        .updateStudy(
          widget.studyId,
          name: name,
          description: _description.text.trim(),
        );
    if (mounted) Navigator.of(context).maybePop(true);
  }

  Future<void> _rename(StepDefinition step) async {
    final l = AppLocalizations.of(context);
    final text = TextEditingController(text: step.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.renameStep),
        content: TextField(
          key: const Key('stepNameField'),
          controller: text,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, text.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(studyRepositoryProvider).renameStep(step.id, name.trim());
    await _load(fields: false);
  }

  Future<void> _add() async {
    final name = _newStep.text.trim();
    if (name.isEmpty) return;
    await ref.read(studyRepositoryProvider).addStep(widget.studyId, name);
    _newStep.clear();
    await _load(fields: false);
  }

  Future<void> _delete(StepDefinition step) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(studyRepositoryProvider);
    final times = await repo.countStepTimes(step.id);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteStep),
        content: Text(
          times == 0
              ? l.deleteStepConfirm(step.name)
              : l.deleteStepWithTimes(step.name, times),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.deleteStep(step.id);
    await _load(fields: false);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = [..._steps];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item); // already adjusted by onReorderItem
    setState(() => _steps = list);
    await ref
        .read(studyRepositoryProvider)
        .reorderSteps(widget.studyId, list.map((s) => s.id).toList());
    await _load(fields: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final study = _study;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.editStudy),
        actions: [
          TextButton(
            key: const Key('saveStudyButton'),
            onPressed: _saveStudy,
            child: Text(l.save),
          ),
        ],
      ),
      body: study == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('studyNameField'),
                        controller: _name,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: l.nameLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _description,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l.descriptionLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (study.mode.usesSteps) ...[
                  ListTile(
                    title: Text(
                      l.stepsSection,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(l.stepsEditHint),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _steps.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, i) {
                        final s = _steps[i];
                        return ListTile(
                          key: ValueKey(s.id),
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Text(s.name),
                          subtitle: Text(l.stepOf(i + 1, _steps.length)),
                          onTap: () => _rename(s),
                          trailing: IconButton(
                            key: Key('deleteStep-$i'),
                            tooltip: l.deleteStep,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(s),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('newStepField'),
                                  controller: _newStep,
                                  decoration: InputDecoration(
                                    hintText: l.newStepHint,
                                  ),
                                  onSubmitted: (_) => _add(),
                                ),
                              ),
                              IconButton(
                                key: const Key('addStepButton'),
                                tooltip: l.addStep,
                                icon: const Icon(Icons.add_circle),
                                onPressed: _add,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          DictationButton(
                            controller: _newStep,
                            multiline: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
    );
  }
}
