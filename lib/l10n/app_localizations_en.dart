// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CycleScope';

  @override
  String get createStudy => 'Create study';

  @override
  String get newStudyTitle => 'New study';

  @override
  String get nameLabel => 'Name';

  @override
  String get descriptionLabel => 'Description (optional)';

  @override
  String get modeSection => 'Study mode';

  @override
  String get modeSimple => 'Simple';

  @override
  String get modeSimpleDesc => 'Standard stopwatch with laps';

  @override
  String get modeSimpleInfo =>
      'A classic stopwatch. Every lap press closes the current lap and starts the next one. No steps needed.';

  @override
  String get modeTimeStudy => 'Time study';

  @override
  String get modeTimeStudyDesc => 'Fixed sequence of defined steps';

  @override
  String get modeTimeStudyInfo =>
      'You define a fixed sequence of steps. Step 1 is active as soon as you start. Each press moves to the next step; after the last step a new cycle begins with step 1. Ideal for repetitive, ordered work.';

  @override
  String get modeStepTimer => 'Step timer';

  @override
  String get modeStepTimerDesc => 'Tap steps in any order, time per step';

  @override
  String get modeStepTimerInfo =>
      'Tap any step to start timing it. The time always runs for the step you tapped last. Useful when the order of work varies.';

  @override
  String get modeVideo => 'Video study';

  @override
  String get modeVideoDesc => 'Import a video and mark steps during playback';

  @override
  String get modeVideoInfo =>
      'Import a recorded video and play it back. Mark every step as it appears in the picture to build your study from the footage, without live timing.';

  @override
  String get modeBadgeSimple => 'SIMPLE';

  @override
  String get modeBadgeTimeStudy => 'TIME STUDY';

  @override
  String get modeBadgeStepTimer => 'STEP TIMER';

  @override
  String get modeBadgeVideo => 'VIDEO';

  @override
  String get howItWorks => 'How it works';

  @override
  String get gotIt => 'Got it';

  @override
  String get stepsLabel => 'Steps (one per line)';

  @override
  String stepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get stepsRequired => 'Please enter at least one step';

  @override
  String defaultStudyName(String number) {
    return 'Time study #$number';
  }

  @override
  String get emptyStudies => 'No studies yet. Create your first time study.';

  @override
  String get createdLabel => 'Created';

  @override
  String get activeLabel => 'Active';

  @override
  String get cyclesLabel => 'CYCLES';

  @override
  String get lapsLabel => 'LAPS';

  @override
  String get measurementsLabel => 'TIMES';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteStudy => 'Delete study';

  @override
  String deleteStudyConfirm(String name) {
    return 'Delete \"$name\" including all measurements?';
  }

  @override
  String get totalLabel => 'TOTAL';

  @override
  String get stepLabel => 'STEP';

  @override
  String get lapLabel => 'LAP';

  @override
  String lapNumber(int number) {
    return 'Lap $number';
  }

  @override
  String cycleNumber(int number) {
    return 'Cycle $number';
  }

  @override
  String stepOf(int index, int count) {
    return 'Step $index of $count';
  }

  @override
  String nextStep(String name) {
    return 'Next: $name';
  }

  @override
  String get ready => 'Ready';

  @override
  String get paused => 'PAUSED';

  @override
  String get recording => 'RECORDING';

  @override
  String get specialTimeRunning => 'SPECIAL TIME';

  @override
  String get specialTime => 'Special time';

  @override
  String get noTimesYet =>
      'No times yet. Press start – step 1 begins immediately.';

  @override
  String get start => 'START';

  @override
  String get stop => 'STOP';

  @override
  String get resume => 'CONTINUE';

  @override
  String get next => 'NEXT';

  @override
  String get lap => 'LAP';

  @override
  String get reset => 'Reset';

  @override
  String get resetConfirm => 'Stop recording and discard the unfinished step?';

  @override
  String get specialShort => 'HOLD\nSPECIAL';

  @override
  String get specialTimeNote => 'Special time note';

  @override
  String get specialTimeNoteHint => 'What happened? (optional)';

  @override
  String get save => 'Save';

  @override
  String get rebootInterrupted =>
      'The device was restarted during the recording. Completed times are kept; the unfinished step was discarded.';

  @override
  String get recordingInProgress => 'Recording in progress';

  @override
  String recordingInProgressText(String name) {
    return '\"$name\" is still being recorded. Continue?';
  }

  @override
  String get open => 'Open';

  @override
  String get discard => 'Discard';

  @override
  String get recBadge => 'REC';
}
