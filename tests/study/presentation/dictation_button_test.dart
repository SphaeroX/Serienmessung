import 'dart:async';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/platform/speech_input.dart';
import 'package:cyclescope/study/presentation/create_study_screen.dart';
import 'package:cyclescope/study/presentation/dictation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

/// Speech input driven by the test.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput({this.available = true});

  final bool available;
  bool listening = false;
  String text = '';
  void Function(String)? _onText;

  /// When set, [start] waits for it (a slow recognizer start).
  Completer<void>? startGate;

  /// When set, [stop] waits for it (the final result arrives late).
  Completer<void>? stopGate;

  bool _stopping = false;
  int stopCalls = 0;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onText,
  }) async {
    if (!available) return false;
    // Like the platform recognizer: busy while the last session ends.
    if (_stopping) return false;
    await startGate?.future;
    listening = true;
    text = '';
    _onText = onText;
    return true;
  }

  void say(String words) {
    text = words;
    _onText?.call(words);
  }

  @override
  Future<String> stop() async {
    stopCalls++;
    _stopping = true;
    await stopGate?.future;
    _stopping = false;
    listening = false;
    return text;
  }
}

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    FakeSpeechInput speech, {
    Locale locale = const Locale('en'),
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          speechInputProvider.overrideWithValue(speech),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const CreateStudyScreen(), locale: locale),
      ),
    );
    await settle(tester);
  }

  testWidgets('hold to dictate, release inserts a step line', (tester) async {
    final speech = FakeSpeechInput();
    await pump(tester, speech);
    await tester.enterText(find.byKey(const Key('stepsField')), 'Pick');
    await tester.pump();

    final button = find.byKey(const Key('dictationButton'));
    await tester.ensureVisible(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(speech.listening, isTrue);

    speech.say('Teil einlegen');
    await tester.pump();
    expect(find.text('Teil einlegen'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(speech.listening, isFalse);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('stepsField')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'Pick\nTeil einlegen');
    expect(find.text('2 steps'), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('the idle label fits on one line ($locale)', (tester) async {
      await pump(tester, FakeSpeechInput(), locale: locale);
      final label = find.descendant(
        of: find.byKey(const Key('dictationButton')),
        matching: find.byType(Text),
      );
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final lineHeight = paragraph.getFullHeightForCaret(
        const TextPosition(offset: 0),
      );
      expect(paragraph.size.height, lessThan(lineHeight * 1.5));
    });
  }

  testWidgets('unavailable recognition shows a hint', (tester) async {
    await pump(tester, FakeSpeechInput(available: false));
    final button = find.byKey(const Key('dictationButton'));
    await tester.ensureVisible(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await gesture.up();
    await pumpFrames(tester, count: 3);
    expect(
      find.text(
        'Speech recognition is not available or microphone access was denied.',
      ),
      findsOneWidget,
    );
  });

  String stepsText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('stepsField')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  Future<void> dictate(
    WidgetTester tester,
    FakeSpeechInput speech,
    String words,
  ) async {
    final button = find.byKey(const Key('dictationButton'));
    await tester.ensureVisible(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    speech.say(words);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('a second dictation works after the first', (tester) async {
    final speech = FakeSpeechInput();
    await pump(tester, speech);
    await dictate(tester, speech, 'Pick');
    await dictate(tester, speech, 'Place');
    await dictate(tester, speech, 'Check');
    expect(stepsText(tester), 'Pick\nPlace\nCheck');
  });

  testWidgets('pressing again while the last result is still arriving waits '
      'for it', (tester) async {
    final speech = FakeSpeechInput()..stopGate = Completer<void>();
    await pump(tester, speech);
    await dictate(tester, speech, 'Pick');

    // Second press before the recognizer has finished the first session.
    final button = find.byKey(const Key('dictationButton'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    final gate = speech.stopGate!;
    speech.stopGate = null;
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(speech.listening, isTrue);
    speech.say('Place');
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(stepsText(tester), 'Pick\nPlace');
  });

  testWidgets('releasing while the recognizer is still starting stops it', (
    tester,
  ) async {
    final speech = FakeSpeechInput()..startGate = Completer<void>();
    await pump(tester, speech);
    final button = find.byKey(const Key('dictationButton'));
    await tester.ensureVisible(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    speech.startGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(speech.listening, isFalse);
    // The button is ready again.
    speech.startGate = null;
    await dictate(tester, speech, 'Pick');
    expect(stepsText(tester), 'Pick');
  });

  testWidgets('the dictation button is a wide button below the steps field', (
    tester,
  ) async {
    await pump(tester, FakeSpeechInput());
    final field = tester.getRect(find.byKey(const Key('stepsField')));
    final button = tester.getRect(find.byKey(const Key('dictationButton')));
    expect(button.top, greaterThanOrEqualTo(field.bottom));
    expect(button.width, closeTo(field.width, 1));
    expect(button.height, greaterThanOrEqualTo(56));
  });
}
