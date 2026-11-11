// Generates the app screenshots in `screenshots/<language>/`.
//
// Not part of the normal test run (skipped). Generate with:
//   flutter test tests/screenshots --dart-define=SCREENSHOTS=true
// The GitHub workflow `screenshots.yml` runs this on every push to main and
// commits the images.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cyclescope/app.dart';
import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/create_study_screen.dart';
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

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _s = 1000000;
const _shotKey = Key('screenshot');

/// Sample data per language.
class _Texts {
  const _Texts({
    required this.study,
    required this.description,
    required this.steps,
    required this.videoStudy,
    required this.timerStudy,
    required this.timerSteps,
    required this.note,
  });

  final String study;
  final String description;
  final List<String> steps;
  final String videoStudy;
  final String timerStudy;
  final List<String> timerSteps;
  final String note;
}

const _texts = {
  'en': _Texts(
    study: 'Assembly line 3 – housing',
    description: 'Early shift, station 4',
    steps: ['Pick housing', 'Insert seal', 'Screw cover', 'Visual check'],
    videoStudy: 'Packing station (video)',
    timerStudy: 'Set-up workshop',
    timerSteps: ['Change tool', 'Measure', 'Clean'],
    note: 'Material missing',
  ),
  'de': _Texts(
    study: 'Montagelinie 3 – Gehäuse',
    description: 'Frühschicht, Station 4',
    steps: [
      'Gehäuse greifen',
      'Dichtung einlegen',
      'Deckel verschrauben',
      'Sichtprüfung',
    ],
    videoStudy: 'Packplatz (Video)',
    timerStudy: 'Rüstwerkstatt',
    timerSteps: ['Werkzeug wechseln', 'Messen', 'Reinigen'],
    note: 'Material fehlt',
  ),
};

/// Video placeholder: the real player cannot run in tests.
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
  // Live timers use the generic monospace family.
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

  Future<void> show(
    WidgetTester tester,
    String lang,
    Widget home, {
    List<Override> extra = const [],
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock as Clock),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 11, 9)),
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

  Future<void> shot(WidgetTester tester, String lang, String name) async {
    await pumpFrames(tester, count: 5);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('screenshots/$lang/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
    await pumpFrames(tester);
  }

  /// Time study with [cycles] recorded cycles (one with a special time).
  Future<int> seedTimeStudy(_Texts t, {int cycles = 6}) async {
    final repo = StudyRepository(db);
    final id = await repo.createStudy(
      name: t.study,
      description: t.description,
      mode: StudyMode.timeStudy,
      steps: t.steps,
      now: DateTime(2026, 11, 10, 7, 30),
    );
    final steps = await repo.getSteps(id);
    final measurements = MeasurementRepository(db);
    const base = [4.2, 7.8, 11.5, 3.1];
    const jitter = [0.0, 0.4, -0.3, 0.7, -0.5, 0.2, 0.1, -0.2];
    var at = 0;
    for (var c = 1; c <= cycles; c++) {
      for (var i = 0; i < steps.length; i++) {
        final d = ((base[i] + jitter[(c + i) % jitter.length]) * _s).round();
        await measurements.insert(
          id,
          MeasurementDraft(
            cycle: c,
            stepId: steps[i].id,
            kind: MeasurementKind.normal,
            startMicros: at,
            endMicros: at + d,
            durationMicros: d,
          ),
        );
        at += d;
        if (c == 3 && i == 1) {
          await measurements.insert(
            id,
            MeasurementDraft(
              cycle: c,
              stepId: steps[i].id,
              kind: MeasurementKind.special,
              startMicros: at,
              endMicros: at + 9 * _s,
              durationMicros: 9 * _s,
              note: t.note,
            ),
          );
          at += 9 * _s;
        }
      }
    }
    return id;
  }

  Future<int> seedVideoStudy(_Texts t) async {
    final repo = StudyRepository(db);
    final id = await repo.createStudy(
      name: t.videoStudy,
      mode: StudyMode.video,
      steps: t.steps.take(3).toList(),
      now: DateTime(2026, 11, 9, 14),
    );
    await repo.setVideoPath(id, 'fake:demo.mp4');
    final steps = await repo.getSteps(id);
    final measurements = MeasurementRepository(db);
    var at = 2 * _s;
    for (var c = 1; c <= 3; c++) {
      for (var i = 0; i < steps.length; i++) {
        final d = (3 + i * 1.5 + c * 0.3) * _s ~/ 1;
        await measurements.insert(
          id,
          MeasurementDraft(
            cycle: c,
            stepId: steps[i].id,
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

  /// Runs [body] with real shadows (tests draw them as black outlines).
  void screenshotTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, skip: !_enabled, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  for (final lang in _texts.keys) {
    final t = _texts[lang]!;

    screenshotTest('$lang: study list', (tester) async {
      await tester.runAsync(() async {
        await seedTimeStudy(t);
        await seedVideoStudy(t);
        await StudyRepository(db).createStudy(
          name: t.timerStudy,
          mode: StudyMode.stepTimer,
          steps: t.timerSteps,
          now: DateTime(2026, 11, 8, 10),
        );
      });
      await show(tester, lang, const StudyListScreen());
      await shot(tester, lang, '01_study_list');
    });

    screenshotTest('$lang: new study', (tester) async {
      await show(tester, lang, const CreateStudyScreen());
      await tester.enterText(find.byKey(const Key('studyNameField')), t.study);
      await tester.enterText(
        find.byKey(const Key('stepsField')),
        t.steps.join('\n'),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFrames(tester);
      await shot(tester, lang, '02_new_study');
    });

    screenshotTest('$lang: live recording, cycles, analysis', (tester) async {
      final id = (await tester.runAsync(() => seedTimeStudy(t)))!;
      await show(tester, lang, RecordingScreen(studyId: id));
      await tap(tester, 'startStopButton');
      clock.advanceSeconds(4.3);
      await tap(tester, 'nextButton');
      clock.advanceSeconds(6.12);
      await pumpFrames(tester);
      await shot(tester, lang, '03_recording_live');

      await tap(tester, 'cyclesTab');
      await tester.tap(find.byKey(const Key('cycleTile-3')));
      await pumpFrames(tester);
      await shot(tester, lang, '04_cycles');

      await tap(tester, 'analysisTab');
      await shot(tester, lang, '05_analysis');
    });

    screenshotTest('$lang: video study', (tester) async {
      final id = (await tester.runAsync(() => seedVideoStudy(t)))!;
      final video = _DemoVideo();
      await show(
        tester,
        lang,
        VideoStudyScreen(studyId: id),
        extra: [
          videoPlaybackFactoryProvider.overrideWithValue(() => video),
          videoPickerProvider.overrideWithValue(FakeVideoPicker()),
        ],
      );
      video.moveTo(31 * _s);
      await pumpFrames(tester);
      await shot(tester, lang, '06_video_study');
    });

    screenshotTest('$lang: settings', (tester) async {
      await show(tester, lang, const SettingsScreen());
      await shot(tester, lang, '07_settings');
    });
  }
}
