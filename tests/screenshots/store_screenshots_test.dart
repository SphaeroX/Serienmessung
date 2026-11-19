// Renders the raw app screenshots for the store listings (Google Play and
// App Store) into `store/raw/<device>/<language>/` (local, ignored by git).
// `tool/generate_store_assets.py` then puts them into captioned frames in
// the sizes each store needs.
//
// Not part of the normal test run (skipped). Generate with:
//   flutter test tests/screenshots/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
//
// The shots use the demo line from the settings (saw, milling centres,
// washer, assembly, test benches, packing with buffers and conveyors).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cyclescope/app.dart';
import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/demo/data/demo_data_service.dart';
import 'package:cyclescope/demo/domain/demo_texts.dart';
import 'package:cyclescope/demo/presentation/demo_data_tile.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:cyclescope/video/presentation/video_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../fakes/fake_video.dart';
import '../helpers.dart';

const _enabled = bool.fromEnvironment('STORE_SCREENSHOTS');
const _s = 1000000;
const _shotKey = Key('storeScreenshot');

/// Render sizes: phone (Android 20:9, also used for iPhone) and a 13"
/// iPad in portrait (2064 x 2752 pixels).
const _devices = {
  'phone': (size: Size(1078, 2398), ratio: 2.75),
  'tablet': (size: Size(2064, 2752), ratio: 2.75),
};

class _DemoVideo extends FakeVideoPlayback {
  @override
  Widget buildView() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF23395B), Color(0xFF0B6B8A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(Icons.precision_manufacturing, size: 72, color: Colors.white),
    ),
  );
}

Future<void> _loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  File font(String name) => dir.listSync().whereType<File>().firstWhere(
    (f) => f.uri.pathSegments.last.toLowerCase() == name,
  );
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = font(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  const roboto = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-italic.ttf',
  ];
  await load('Roboto', roboto);
  await load('monospace', roboto);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

void main() {
  late AppDatabase db;
  late FakeClock clock;

  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(1000 * _s);
  });

  tearDown(() => db.close());

  for (final device in _devices.entries) {
    for (final lang in const ['en', 'de']) {
      testWidgets('$lang ${device.key}: store screenshots', skip: !_enabled, (
        tester,
      ) async {
        debugDisableShadows = false;
        tester.view.physicalSize = device.value.size;
        tester.view.devicePixelRatio = device.value.ratio;
        addTearDown(tester.view.reset);
        final l = lookupAppLocalizations(Locale(lang));
        final texts = _storeTexts(demoTextsOf(l), lang);

        Future<void> show(
          Widget home, {
          List<Override> extra = const [],
        }) async {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                databaseProvider.overrideWithValue(db),
                clockProvider.overrideWithValue(clock as Clock),
                wallClockProvider.overrideWithValue(
                  () => DateTime(2026, 11, 11, 9),
                ),
                ...fakePlatformOverrides(),
                ...extra,
              ],
              child: RepaintBoundary(
                key: _shotKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildTheme(Brightness.light),
                  locale: Locale(lang),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: home,
                ),
              ),
            ),
          );
          await settle(tester);
          await pumpFrames(tester);
        }

        Future<void> shot(String name) async {
          await pumpFrames(tester, count: 5);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_shotKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(
              pixelRatio: tester.view.devicePixelRatio,
            );
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('store/raw/${device.key}/$lang/$name.png')
              ..createSync(recursive: true)
              ..writeAsBytesSync(png!.buffer.asUint8List());
          });
        }

        late int groupId;
        late int assemblyId;
        late int videoId;
        await tester.runAsync(() async {
          groupId = await DemoDataService(
            db,
            now: () => DateTime(2026, 11, 11, 9),
          ).load(texts);
          final studies = await StudyRepository(db)
              .listStudies(groupId: groupId);
          assemblyId = studies
              .firstWhere((s) => s.study.name == texts.assembly)
              .study
              .id;
          videoId = await _seedVideoStudy(db, l, texts.assemblySteps);
        });

        // 1. Line balancing chart of the demo line.
        await show(LineScreen(groupId: groupId));
        await settle(tester);
        await shot('01_line');

        // 2. Study list (before a recording is left running).
        await show(const StudyListScreen());
        await shot('08_study_list');

        // 2. Simulation: the saw fails for 40 minutes; the buffer in front
        // of the milling centres keeps the bottleneck busy.
        await show(SimulationScreen(groupId: groupId));
        await settle(tester);
        await tester.tap(find.byKey(const Key('horizon24h')));
        await pumpFrames(tester);
        await tester.tap(find.byKey(const Key('failureMachine')));
        await pumpFrames(tester);
        await tester.tap(find.textContaining(texts.saw).last);
        await pumpFrames(tester);
        await tester.enterText(find.byKey(const Key('failureStartField')), '6');
        await tester.enterText(
          find.byKey(const Key('failureDurationField')),
          '40',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFrames(tester);
        await tester.tap(find.byKey(const Key('runSimulation')));
        await settle(tester);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await settle(tester);
        await tester.ensureVisible(find.byKey(const Key('failureMachine')));
        await settle(tester);
        await shot('02_simulation');

        // 3. The line as a group: parallel machines, buffers, conveyors.
        await show(GroupScreen(groupId: groupId));
        await shot('03_group');

        // 4. Live recording of the assembly.
        await show(RecordingScreen(studyId: assemblyId));
        await tester.tap(find.byKey(const Key('startStopButton')));
        await settle(tester);
        clock.advanceSeconds(9.4);
        await tester.tap(find.byKey(const Key('nextButton')));
        await settle(tester);
        clock.advanceSeconds(7.86);
        await pumpFrames(tester);
        await shot('04_recording_live');

        // 5. Analysis with the real cycle time.
        await tester.tap(find.byKey(const Key('analysisTab')));
        await settle(tester);
        await pumpFrames(tester);
        await shot('05_analysis');

        // 6. Video study.
        final video = _DemoVideo();
        await show(
          VideoStudyScreen(studyId: videoId),
          extra: [
            videoPlaybackFactoryProvider.overrideWithValue(() => video),
            videoPickerProvider.overrideWithValue(FakeVideoPicker()),
          ],
        );
        video.moveTo(31 * _s);
        await pumpFrames(tester);
        await shot('06_video_study');

        // 7. Report export of the line (PDF and Excel).
        await show(GroupScreen(groupId: groupId));
        await tester.tap(find.byKey(const Key('groupExportButton')));
        await settle(tester);
        await pumpFrames(tester);
        await shot('07_export');

        debugDisableShadows = true;
      });
    }
  }
}

/// The demo texts without the "Demo:" prefix and with short names for the
/// milling centres, so the bottleneck tile of the line view fits on a phone.
DemoTexts _storeTexts(DemoTexts t, String lang) => DemoTexts(
  groupName: lang == 'de' ? 'Gehäuselinie' : 'Housing line',
  groupDescription: t.groupDescription,
  saw: t.saw,
  bladeChange: t.bladeChange,
  millingCentre: (n) => lang == 'de' ? 'BAZ $n' : 'CNC mill $n',
  millingSteps: t.millingSteps,
  chipJam: t.chipJam,
  measurePart: t.measurePart,
  toolChange: t.toolChange,
  washer: t.washer,
  coverPress: t.coverPress,
  sealCutter: t.sealCutter,
  assembly: t.assembly,
  assemblySteps: t.assemblySteps,
  materialMissing: t.materialMissing,
  testBench: t.testBench,
  calibration: t.calibration,
  packing: t.packing,
  changeover: t.changeover,
  changeoverSteps: t.changeoverSteps,
  cellMachine: t.cellMachine,
  cellMachineSteps: t.cellMachineSteps,
  cellLoader: t.cellLoader,
  cellLoader1Steps: t.cellLoader1Steps,
  cellLoader2Steps: t.cellLoader2Steps,
  cellMagazineLoader: t.cellMagazineLoader,
);

Future<int> _seedVideoStudy(
  AppDatabase db,
  AppLocalizations l,
  List<String> steps,
) async {
  final repo = StudyRepository(db);
  final id = await repo.createStudy(
    name: '${l.demoPacking} (Video)',
    mode: StudyMode.video,
    steps: steps.take(3).toList(),
    now: DateTime(2026, 11, 9, 14),
  );
  await repo.setVideoPath(id, 'fake:demo.mp4');
  final stepDefs = await repo.getSteps(id);
  final measurements = MeasurementRepository(db);
  var at = 2 * _s;
  for (var c = 1; c <= 3; c++) {
    for (var i = 0; i < stepDefs.length; i++) {
      final d = (3 + i * 1.5 + c * 0.3) * _s ~/ 1;
      await measurements.insert(
        id,
        MeasurementDraft(
          cycle: c,
          stepId: stepDefs[i].id,
          kind: MeasurementKind.normal,
          startMicros: at,
          endMicros: at + d,
          durationMicros: d,
        ),
      );
      at += d;
    }
  }
  return id;
}
