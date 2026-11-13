import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../data/demo_data_service.dart';
import '../domain/demo_texts.dart';

/// The demo data names in the language of [l].
DemoTexts demoTextsOf(AppLocalizations l) => DemoTexts(
  groupName: l.demoGroupName,
  groupDescription: l.demoGroupDescription,
  saw: l.demoSaw,
  bladeChange: l.demoBladeChange,
  millingCentre: l.demoMillingCentre,
  millingSteps: [
    l.demoStepLoadPart,
    l.demoStepMill,
    l.demoStepDrill,
    l.demoStepUnload,
  ],
  chipJam: l.demoChipJam,
  measurePart: l.demoMeasurePart,
  toolChange: l.demoToolChange,
  washer: l.demoWasher,
  assembly: l.demoAssembly,
  assemblySteps: [
    l.demoStepPickHousing,
    l.demoStepInsertSeal,
    l.demoStepScrewCover,
    l.demoStepVisualCheck,
  ],
  materialMissing: l.demoMaterialMissing,
  testBench: l.demoTestBench,
  calibration: l.demoCalibration,
  packing: l.demoPacking,
  changeover: l.demoChangeover,
  changeoverSteps: [
    l.demoStepRemoveFixture,
    l.demoStepCleanTable,
    l.demoStepMountFixture,
    l.demoStepFirstPart,
  ],
);

/// Settings tile that adds the demo data after a confirmation.
class DemoDataTile extends ConsumerWidget {
  const DemoDataTile({super.key});

  Future<void> _load(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.loadDemoData),
        content: Text(l.loadDemoDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('loadDemoDataConfirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.load),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final texts = demoTextsOf(l);
    await DemoDataService(
      ref.read(databaseProvider),
      now: ref.read(wallClockProvider),
    ).load(texts);
    ref
      ..invalidate(studyListProvider)
      ..invalidate(groupListProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l.demoDataLoaded(texts.groupName))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const Key('loadDemoDataTile'),
      leading: const Icon(Icons.factory_outlined),
      title: Text(l.loadDemoData),
      subtitle: Text(l.loadDemoDataHint),
      onTap: () => _load(context, ref),
    );
  }
}
