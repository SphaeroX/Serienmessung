import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late int groupId;

  Future<int> study(String name, List<int> seconds, {StudyMode? mode}) async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: name,
      mode: mode ?? StudyMode.timeStudy,
      steps: [for (var i = 0; i < seconds.length; i++) 'Step ${i + 1}'],
      now: DateTime(2026),
    );
    final steps = await studies.getSteps(id);
    for (var i = 0; i < seconds.length; i++) {
      await MeasurementRepository(db).insert(
        id,
        MeasurementDraft(
          cycle: mode == StudyMode.stepTimer ? 0 : 1,
          stepId: steps[i].id,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: seconds[i] * 1000000,
          durationMicros: seconds[i] * 1000000,
        ),
      );
    }
    await GroupRepository(db).moveToGroup(id, groupId);
    return id;
  }

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line 4', now: DateTime(2026));
    await study('Saw', [10, 20]);
    await study('Drill', [60]);
    await study('Set-up', [5], mode: StudyMode.stepTimer);
  });

  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        const AppSettings(defaultUnit: TimeUnit.seconds),
      ),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  testWidgets('shows the line figures, bottleneck and stations in order', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('lineTotal'), '90.00 s');
    expect(text('lineCycleTime'), '60.00 s');
    expect(text('lineBottleneck'), 'Drill');
    expect(text('lineBalance'), '75.0 %');
    expect(text('lineOutput'), '60.0');
    expect(find.byKey(const Key('yamazumiChart')), findsOneWidget);

    await tester.scrollUntilVisible(find.text('3. Set-up'), 200);
    expect(find.text('1. Saw'), findsOneWidget);
    expect(find.text('2. Drill'), findsOneWidget);
    expect(find.textContaining('Waiting: 30.00 s'), findsOneWidget);
  });

  testWidgets('the group screen opens the line analysis', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(GroupScreen(groupId: groupId)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('lineAnalysisButton')));
    await pumpFrames(tester);
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
    expect(find.byType(LineScreen), findsOneWidget);
    expect(find.byKey(const Key('lineTotal')), findsOneWidget);
  });
}
