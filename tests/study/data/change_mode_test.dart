import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late StudyRepository studies;
  late GroupRepository groups;
  late MachineService machines;

  setUp(() async {
    db = await openTestDatabase();
    studies = StudyRepository(db);
    groups = GroupRepository(db);
    machines = MachineService(db, now: () => DateTime(2026));
  });

  tearDown(() => db.close());

  test('a machine with a fixed cycle time becomes a time study', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final saw = await studies.createStudy(
      name: 'Saw',
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
    await groups.moveToGroup(saw, g);
    final id = await machines.createMachine(
      name: 'Mill',
      groupId: g,
      cycleMicros: 5000000,
      parallel: true,
    );
    // An archived revision as well.
    await machines.setCycleTime(id, 6000000);

    await studies.changeMode(id, StudyMode.timeStudy, steps: ['Load', 'Mill']);

    final study = (await studies.getStudy(id))!;
    expect(study.mode, StudyMode.timeStudy);
    expect(study.groupId, g);
    expect(study.parallel, isTrue);
    expect((await studies.getSteps(id)).map((s) => s.name), ['Load', 'Mill']);
    expect(await MeasurementRepository(db).listForStudy(id), isEmpty);
    expect(await RevisionRepository(db).listRevisions(id), isEmpty);
  });

  test('a time study becomes a simple study without steps', () async {
    final id = await studies.createStudy(
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
      now: DateTime(2026),
    );

    await studies.changeMode(id, StudyMode.simple);

    expect((await studies.getStudy(id))!.mode, StudyMode.simple);
    expect(await studies.getSteps(id), isEmpty);
  });

  test('a video study loses its video', () async {
    final id = await studies.createStudy(
      name: 'V',
      mode: StudyMode.video,
      steps: const [],
      now: DateTime(2026),
    );
    await studies.setVideoPath(id, '/videos/a.mp4');

    await studies.changeMode(id, StudyMode.stepTimer, steps: ['A']);

    final study = (await studies.getStudy(id))!;
    expect(study.mode, StudyMode.stepTimer);
    expect(study.videoPath, isNull);
    expect(await studies.isVideoUsed('/videos/a.mp4'), isFalse);
  });
}
