import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../fakes/fake_video_files.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;
  late FakeVideoFiles videos;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
    videos = FakeVideoFiles();
    groupId = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> study(String name, {bool inGroup = true, String? video}) async {
    final id = await studies.createStudy(
      name: name,
      mode: video == null ? StudyMode.timeStudy : StudyMode.video,
      steps: ['A'],
      now: DateTime(2026),
    );
    if (video != null) await studies.setVideoPath(id, video);
    if (inGroup) await groups.moveToGroup(id, groupId);
    return id;
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
          ...fakePlatformOverrides(videoFiles: videos),
        ],
        child: localizedApp(GroupScreen(groupId: groupId)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('groupMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteGroup')));
    await tester.pumpAndSettle();
  }

  testWidgets('the group can be deleted together with its studies', (
    tester,
  ) async {
    late int saw;
    late int film;
    late int loose;
    await tester.runAsync(() async {
      saw = await study('Saw');
      film = await study('Film', video: 'videos/line.mp4');
      loose = await study('Loose', inGroup: false);
    });
    await openDeleteDialog(tester);

    // Off by default: the studies are kept.
    expect(find.textContaining('studies are kept'), findsOneWidget);
    final option = find.byKey(const Key('deleteGroupStudies'));
    expect(tester.widget<CheckboxListTile>(option).value, isFalse);
    expect(
      find.text('Also delete the 2 studies of this group'),
      findsOneWidget,
    );

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(option).value, isTrue);
    expect(find.textContaining('studies are kept'), findsNothing);
    expect(
      find.text(
        'Delete the group "Line 4" and its 2 studies including all '
        'measurements? This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(groupId)), isNull);
    expect(await tester.runAsync(() => studies.getStudy(saw)), isNull);
    expect(await tester.runAsync(() => studies.getStudy(film)), isNull);
    expect(await tester.runAsync(() => studies.getStudy(loose)), isNotNull);
    // The video of the deleted video study goes with it.
    expect(videos.deleted, ['videos/line.mp4']);
  });

  testWidgets('a video another study still plays is kept', (tester) async {
    await tester.runAsync(() async {
      await study('Film', video: 'videos/line.mp4');
      await study('Copy', inGroup: false, video: 'videos/line.mp4');
    });
    await openDeleteDialog(tester);
    await tester.tap(find.byKey(const Key('deleteGroupStudies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(groupId)), isNull);
    expect(videos.deleted, isEmpty);
  });

  testWidgets('without the option the studies stay', (tester) async {
    late int saw;
    await tester.runAsync(() async => saw = await study('Saw'));
    await openDeleteDialog(tester);
    await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(groupId)), isNull);
    final kept = await tester.runAsync(() => studies.getStudy(saw));
    expect(kept, isNotNull);
    expect(kept!.groupId, isNull);
    expect(videos.deleted, isEmpty);
  });

  testWidgets('one study is counted in the singular', (tester) async {
    await tester.runAsync(() => study('Saw'));
    await openDeleteDialog(tester);
    expect(find.text('Also delete the 1 study of this group'), findsOneWidget);
  });

  testWidgets('an empty group offers no such option', (tester) async {
    await openDeleteDialog(tester);
    expect(find.byKey(const Key('deleteGroupStudies')), findsNothing);
    await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(groupId)), isNull);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    late int saw;
    await tester.runAsync(() async => saw = await study('Saw'));
    await openDeleteDialog(tester);
    await tester.tap(find.byKey(const Key('deleteGroupStudies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(groupId)), isNotNull);
    expect(await tester.runAsync(() => studies.getStudy(saw)), isNotNull);
  });
}
