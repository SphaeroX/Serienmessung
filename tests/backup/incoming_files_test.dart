import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/backup/platform/incoming_files.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('platform channel', () {
    const channel = MethodChannel('dev.cyclescope/incoming_files');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    /// The native side tells Dart that new files wait.
    Future<void> nativeSaysFilesWaiting() async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('filesWaiting'),
        ),
        (_) {},
      );
    }

    test('takes the files waiting since the app started', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return ['{"a":1}'];
      });
      final got = <String>[];
      final sub = PlatformIncomingFiles().files.listen(got.add);
      await pumpEventQueue();
      expect(calls, ['takeIncomingFiles']);
      expect(got, ['{"a":1}']);
      await sub.cancel();
    });

    test('takes new files when the platform says they wait', () async {
      var round = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        round++;
        return round == 1 ? <String>[] : ['first', 'second'];
      });
      final got = <String>[];
      final sub = PlatformIncomingFiles().files.listen(got.add);
      await pumpEventQueue();
      expect(got, isEmpty);
      await nativeSaysFilesWaiting();
      await pumpEventQueue();
      expect(got, ['first', 'second']);
      await sub.cancel();
    });

    test('stays silent without a platform implementation', () async {
      final got = <String>[];
      final errors = <Object>[];
      final sub = PlatformIncomingFiles().files.listen(
        got.add,
        onError: errors.add,
      );
      await pumpEventQueue();
      expect(got, isEmpty);
      expect(errors, isEmpty);
      await sub.cancel();
    });
  });

  group('home screen', () {
    late AppDatabase db;
    late FakeIncomingFiles incoming;

    setUp(() async {
      db = await openTestDatabase();
      incoming = FakeIncomingFiles();
    });

    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            ...fakePlatformOverrides(incomingFiles: incoming),
          ],
          child: localizedApp(const StudyListScreen(checkActiveRuns: false)),
        ),
      );
      await settle(tester);
    }

    testWidgets('a file opened with the app is imported', (tester) async {
      final json = await tester.runAsync(() async {
        final other = await openTestDatabase();
        await StudyRepository(other).createStudy(
          name: 'From colleague',
          mode: StudyMode.timeStudy,
          steps: ['A'],
          now: DateTime(2025),
        );
        final j = await BackupService(other).exportJson(now: DateTime(2026));
        await other.close();
        return j;
      });
      await pump(tester);
      incoming.receive(json!);
      await settleUntil(
        tester,
        () => find.text('From colleague').evaluate().isNotEmpty,
      );
      await pumpFrames(tester, count: 3);
      expect(find.text('From colleague'), findsOneWidget);
      expect(find.textContaining('1 study imported.'), findsOneWidget);
    });

    testWidgets('an invalid opened file is reported', (tester) async {
      await pump(tester);
      incoming.receive('not json');
      await settle(tester);
      await pumpFrames(tester, count: 3);
      expect(find.textContaining('cannot be imported'), findsOneWidget);
    });
  });
}
