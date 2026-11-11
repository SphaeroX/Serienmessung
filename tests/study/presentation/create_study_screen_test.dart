import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/create_study_screen.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: localizedApp(home),
  );

  testWidgets('cannot create a time study without steps', (tester) async {
    await tester.pumpWidget(app(const CreateStudyScreen()));
    await settle(tester);

    await tester.tap(find.text('Time study').first);
    await tester.pump();
    await tapVisible(tester, find.byKey(const Key('createStudyButton')));
    await settle(tester);

    expect(find.text('Please enter at least one step'), findsOneWidget);
    final list = await tester.runAsync(() => StudyRepository(db).listStudies());
    expect(list, isEmpty);
  });

  testWidgets('cannot create a study without a name', (tester) async {
    await tester.pumpWidget(app(const CreateStudyScreen()));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('studyNameField')), '');
    await tapVisible(tester, find.byKey(const Key('createStudyButton')));
    await settle(tester);

    expect(find.text('Please enter a name'), findsOneWidget);
  });

  testWidgets('shows the number of recognized steps', (tester) async {
    await tester.pumpWidget(app(const CreateStudyScreen()));
    await settle(tester);
    await tester.tap(find.text('Time study').first);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('stepsField')), 'A\n\nB\nC');
    await tester.pump();
    expect(find.text('3 steps'), findsOneWidget);
  });

  testWidgets('created study appears in the list with its mode badge', (
    tester,
  ) async {
    await tester.pumpWidget(app(const StudyListScreen()));
    await settle(tester);
    expect(
      find.text('No studies yet. Create your first time study.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('newStudyFab')));
    await settle(tester);

    await tester.enterText(
      find.byKey(const Key('studyNameField')),
      'Conveyor 200',
    );
    await tester.tap(find.text('Time study').first);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('stepsField')), 'Pick\nPlace');
    await tapVisible(tester, find.byKey(const Key('createStudyButton')));
    await settle(tester);

    // Creating opens the study; go back to the list.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await settle(tester);

    expect(find.text('Conveyor 200'), findsOneWidget);
    expect(find.text('TIME STUDY'), findsOneWidget);
  });

  testWidgets('a video study is created without steps', (tester) async {
    await tester.pumpWidget(app(const CreateStudyScreen()));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('studyNameField')), 'Clip');
    await tapVisible(tester, find.text('Video study').first);
    await tester.pump();
    expect(find.byKey(const Key('stepsField')), findsNothing);
    expect(find.byKey(const Key('dictationButton')), findsNothing);

    await tapVisible(tester, find.byKey(const Key('createStudyButton')));
    await settle(tester);
    final repo = StudyRepository(db);
    final list = (await tester.runAsync(repo.listStudies))!;
    expect(list.single.study.mode, StudyMode.video);
    expect(list.single.study.stepsOpen, isTrue);
    expect(
      await tester.runAsync(() => repo.getSteps(list.single.study.id)),
      isEmpty,
    );
  });
}
