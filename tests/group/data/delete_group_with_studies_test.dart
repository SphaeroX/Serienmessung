import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
  });

  tearDown(() => db.close());

  /// A study with one time, optionally in group [groupId].
  Future<int> study(String name, {int? groupId}) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    await MeasurementRepository(db).insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: (await studies.getSteps(id)).single.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 1000000,
        durationMicros: 1000000,
      ),
    );
    if (groupId != null) await groups.moveToGroup(id, groupId);
    return id;
  }

  Future<int> count(String table) async =>
      (await db.db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n']
          as int;

  test('deleting a group with its studies removes them with all their '
      'data', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final saw = await study('Saw', groupId: g);
    final drill = await study('Drill', groupId: g);
    await RevisionRepository(db).startNewRevision(saw, now: DateTime(2026, 2));
    await SpecialCycleRepository(db).add(
      drill,
      name: 'Tool change',
      kind: SpecialCycleKind.parts,
      interval: 10,
      durationMicros: 1000000,
    );

    await groups.deleteGroup(g, withStudies: true);

    expect(await groups.getGroup(g), isNull);
    expect(await studies.getStudy(saw), isNull);
    expect(await studies.getStudy(drill), isNull);
    for (final table in [
      'study',
      'step_definition',
      'measurement',
      'revision',
      'revision_step',
      'revision_measurement',
      'special_cycle',
    ]) {
      expect(await count(table), 0, reason: table);
    }
  });

  test('studies of other groups and loose studies stay', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final other = await groups.createGroup(name: 'Other', now: DateTime(2026));
    await study('Saw', groupId: g);
    final kept = await study('Press', groupId: other);
    final loose = await study('Loose');

    await groups.deleteGroup(g, withStudies: true);

    expect((await studies.listStudies()).map((s) => s.study.id).toSet(), {
      kept,
      loose,
    });
    expect((await studies.getStudy(kept))!.groupId, other);
    expect(await count('measurement'), 2);
    expect(await groups.listGroups(), hasLength(1));
  });

  test('without the option the studies are kept without a group', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final saw = await study('Saw', groupId: g);
    await groups.deleteGroup(g);
    expect((await studies.getStudy(saw))!.groupId, isNull);
    expect(await count('measurement'), 1);
  });
}
