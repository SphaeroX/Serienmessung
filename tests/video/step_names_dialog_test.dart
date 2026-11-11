import 'package:cyclescope/video/presentation/step_names_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late List<String>? result;

  Future<void> open(WidgetTester tester, List<String> names) async {
    result = const ['not closed'];
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<List<String>>(
                context: context,
                builder: (_) => StepNamesDialog(names: names),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns the names unchanged when saved as suggested', (
    tester,
  ) async {
    await open(tester, ['Step 1', 'Step 2', 'Step 3', 'Step 4']);
    expect(find.byKey(const Key('stepNameField-3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('saveStepNames')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, ['Step 1', 'Step 2', 'Step 3', 'Step 4']);
  });

  testWidgets('returns edited names, blank ones keep their old name', (
    tester,
  ) async {
    await open(tester, ['Step 1', 'Step 2']);
    await tester.enterText(find.byKey(const Key('stepNameField-0')), ' Pick ');
    await tester.enterText(find.byKey(const Key('stepNameField-1')), '  ');
    await tester.tap(find.byKey(const Key('saveStepNames')));
    await tester.pumpAndSettle();
    expect(result, ['Pick', 'Step 2']);
  });

  testWidgets('cancel returns null', (tester) async {
    await open(tester, ['Step 1']);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
