import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
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
  late GroupRepository groups;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
  });

  tearDown(() => db.close());

  Future<int> study(String name, int seconds, int groupId) async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: const ['Work'],
      now: DateTime(2026),
    );
    final steps = await studies.getSteps(id);
    await MeasurementRepository(db).insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: steps.single.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: seconds * 1000000,
        durationMicros: seconds * 1000000,
      ),
    );
    await groups.moveToGroup(id, groupId);
    return id;
  }

  Future<int> newGroup(String name, {int? parent}) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

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

  Future<void> open(WidgetTester tester, int groupId) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
  }

  testWidgets('a plant shows its areas, running station numbers and '
      'headings', (tester) async {
    late int plant;
    late int press;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', 30, plant);
      press = await newGroup('Press', parent: plant);
      await study('Punch', 50, press);
      await study('Bend', 20, press);
      await study('Pack', 45, plant);
    });
    await open(tester, plant);

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('lineCycleTime'), '50.00 s');
    expect(text('lineBottleneck'), 'Punch');

    final row = find.byKey(Key('lineArea_$press'));
    await tester.scrollUntilVisible(row, 200);
    expect(
      find.descendant(of: row, matching: find.textContaining('Press')),
      findsWidgets,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('Stations 2–3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('Alone: 72.0 parts/h'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('Bottleneck area'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(Key('lineAreaHeading_$press')),
      200,
    );
    await tester.scrollUntilVisible(find.text('4. Pack'), 200);
    expect(find.text('2. Punch'), findsOneWidget);
    expect(find.text('3. Bend'), findsOneWidget);

    // Tapping the area opens its own line analysis.
    await tester.scrollUntilVisible(row, -200);
    await tester.tap(row);
    await pumpFrames(tester);
    await settleUntil(
      tester,
      () => find.text('Line analysis · Press').evaluate().isNotEmpty,
    );
    expect(find.text('Line analysis · Press'), findsOneWidget);
  });

  testWidgets('a group without areas shows no area card', (tester) async {
    late int line;
    await tester.runAsync(() async {
      line = await newGroup('Line');
      await study('Saw', 30, line);
      await study('Drill', 40, line);
    });
    await open(tester, line);
    expect(find.byKey(const Key('lineAreas')), findsNothing);
    expect(find.textContaining('Bottleneck area'), findsNothing);
  });

  testWidgets('with 40 stations the chart scrolls sideways', (tester) async {
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      for (var a = 0; a < 4; a++) {
        final area = await newGroup('Area $a', parent: plant);
        for (var i = 0; i < 10; i++) {
          await study('S$a-$i', 20 + i, area);
        }
      }
    });
    await open(tester, plant);
    await tester.scrollUntilVisible(
      find.byKey(const Key('yamazumiScroll')),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    final chart = tester.getSize(find.byKey(const Key('yamazumiChart')));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(chart.width, greaterThan(screen.width));
    expect(chart.width, greaterThanOrEqualTo(40 * 24));
    expect(find.byKey(const Key('yamazumiScroll')), findsOneWidget);
  });

  testWidgets('the simulation screen opens for a plant', (tester) async {
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', 30, plant);
      final press = await newGroup('Press', parent: plant);
      await study('Punch', 50, press);
      await study('Pack', 45, plant);
    });
    usePhoneSize(tester);
    await tester.pumpWidget(app(SimulationScreen(groupId: plant)));
    await settle(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Punch'), findsWidgets);
  });
}
