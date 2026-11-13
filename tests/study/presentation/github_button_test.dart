import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/study/presentation/github_logo.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late FakeUrlOpener opener;

  setUp(() async {
    db = await openTestDatabase();
    opener = FakeUrlOpener();
  });

  tearDown(() => db.close());

  Widget app({Locale locale = const Locale('en')}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      ...fakePlatformOverrides(urlOpener: opener),
    ],
    child: localizedApp(const StudyListScreen(), locale: locale),
  );

  testWidgets('app bar shows the GitHub logo', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    final button = find.byKey(const Key('githubButton'));
    expect(
      find.descendant(of: find.byType(AppBar), matching: button),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.byType(GitHubLogo)),
      findsOneWidget,
    );
    expect(find.byTooltip('Source code on GitHub'), findsOneWidget);
  });

  testWidgets('tapping the logo opens the repository', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('githubButton')));
    await settle(tester);
    expect(opener.opened, [
      Uri.parse('https://github.com/SphaeroX/Serienmessung'),
    ]);
    expect(find.text('Could not open the link.'), findsNothing);
  });

  testWidgets('tells the user when the link cannot be opened', (tester) async {
    opener.result = false;
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('githubButton')));
    await settle(tester);
    expect(find.text('Could not open the link.'), findsOneWidget);
  });

  testWidgets('tooltip is translated', (tester) async {
    await tester.pumpWidget(app(locale: const Locale('de')));
    await settle(tester);
    expect(find.byTooltip('Quellcode auf GitHub'), findsOneWidget);
  });
}
