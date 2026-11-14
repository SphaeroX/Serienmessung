import 'package:cyclescope/study/domain/step_text_sync.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

StepDefinition step(int id, String name) =>
    StepDefinition(id: id, studyId: 1, position: id, name: name);

void main() {
  final existing = [step(1, 'Pick'), step(2, 'Place'), step(3, 'Press')];

  test('unchanged text keeps every step', () {
    final plan = planStepText(existing, 'Pick\nPlace\nPress');
    expect(plan.steps, const [
      StepEdit(id: 1, name: 'Pick'),
      StepEdit(id: 2, name: 'Place'),
      StepEdit(id: 3, name: 'Press'),
    ]);
    expect(plan.deletedIds, isEmpty);
  });

  test('reordered lines keep their step ids', () {
    final plan = planStepText(existing, 'Press\nPick\nPlace');
    expect(plan.steps.map((s) => s.id), [3, 1, 2]);
    expect(plan.deletedIds, isEmpty);
  });

  test('new lines become new steps', () {
    final plan = planStepText(existing, 'Pick\nPlace\nPress\nCheck');
    expect(plan.steps.last, const StepEdit(id: null, name: 'Check'));
  });

  test('removed lines delete their steps', () {
    final plan = planStepText(existing, 'Pick\nPress');
    expect(plan.steps.map((s) => s.id), [1, 3]);
    expect(plan.deletedIds, [2]);
  });

  test('a changed line renames the step and keeps its id', () {
    final plan = planStepText(existing, 'Pick\nPlace part\nPress');
    expect(plan.steps[1], const StepEdit(id: 2, name: 'Place part'));
    expect(plan.deletedIds, isEmpty);
  });

  test('an edited line keeps its step when a line is inserted before', () {
    final plan = planStepText(existing, 'Check\nPick part\nPlace\nPress');
    expect(plan.steps.map((s) => s.id), [null, 1, 2, 3]);
    expect(plan.deletedIds, isEmpty);
  });

  test('a different line replaces the step instead of renaming it', () {
    final plan = planStepText(existing, 'Pick\nWeld\nPress');
    expect(plan.steps[1], const StepEdit(id: null, name: 'Weld'));
    expect(plan.deletedIds, [2]);
  });

  test('a corrected typo or changed case still renames', () {
    final plan = planStepText(existing, 'pick\nPlcae\nPress');
    expect(plan.steps.map((s) => s.id), [1, 2, 3]);
  });

  test('duplicate names match existing steps one by one', () {
    final plan = planStepText([
      step(1, 'Check'),
      step(2, 'Check'),
    ], 'Check\nCheck\nCheck');
    expect(plan.steps.map((s) => s.id), [1, 2, null]);
  });

  test('blank lines and surrounding spaces are ignored', () {
    final plan = planStepText(existing, '  Pick \n\nPlace\n Press');
    expect(plan.steps.map((s) => s.id), [1, 2, 3]);
  });

  test('empty text deletes every step', () {
    final plan = planStepText(existing, '\n');
    expect(plan.steps, isEmpty);
    expect(plan.deletedIds, [1, 2, 3]);
  });
}
