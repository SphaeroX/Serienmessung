import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/platform/speech_input.dart';
import 'package:cyclescope/study/presentation/create_study_screen.dart';
import 'package:cyclescope/study/presentation/dictation_button.dart';
import 'package:flutter/material.dart';
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

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onText,
  }) async {
    if (!available) return false;
    listening = true;
    _onText = onText;
    return true;
  }

  void say(String words) {
    text = words;
    _onText?.call(words);
  }

  @override
  Future<String> stop() async {
    listening = false;
    return text;
  }
}

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, FakeSpeechInput speech) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          speechInputProvider.overrideWithValue(speech),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const CreateStudyScreen()),
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
}
