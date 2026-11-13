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
  String get modeVideoDesc =>
      'Import a video and define the steps while marking it';

  @override
  String get modeVideoInfo =>
      'Import a recorded video and play it back. No steps are needed beforehand: in the first cycle every marker starts a new step. Tap “Cycle complete” at the end of the cycle and name the steps. Further markers then follow these steps cycle by cycle. Afterwards you can use the steps for a live time study.';

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

  @override
  String get tabLive => 'Live';

  @override
  String get replaceVideoTitle => 'Replace video?';

  @override
  String get replaceVideoBody =>
      'The recorded cycles belong to the current video. Delete them or keep them?';

  @override
  String get keepCycles => 'Keep';

  @override
  String get deleteCycles => 'Delete cycles';

  @override
  String get tabMark => 'Mark';

  @override
  String get tabCycles => 'Cycles';

  @override
  String get tabLaps => 'Laps';

  @override
  String get incomplete => 'incomplete';

  @override
  String get deleteCycle => 'Delete cycle';

  @override
  String get undo => 'Undo';

  @override
  String deletedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times deleted',
      one: '1 time deleted',
    );
    return '$_temp0';
  }

  @override
  String get editStudy => 'Edit study';

  @override
  String get renameStep => 'Rename step';

  @override
  String get deleteStep => 'Delete step';

  @override
  String deleteStepConfirm(String name) {
    return 'Delete step \"$name\"?';
  }

  @override
  String deleteStepWithTimes(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded times',
      one: '1 recorded time',
    );
    return 'Delete step \"$name\" including $_temp0?';
  }

  @override
  String get stepsSection => 'Steps';

  @override
  String get stepsEditHint =>
      'Tap to rename, drag to reorder. Recorded times stay with their step.';

  @override
  String get newStepHint => 'New step';

  @override
  String get addStep => 'Add step';

  @override
  String get tabAnalysis => 'Analysis';

  @override
  String get realCycleTime => 'Real cycle time';

  @override
  String get realLapTime => 'Real lap time';

  @override
  String get methodMean => 'Mean';

  @override
  String get methodMedian => 'Median';

  @override
  String get methodIqr => 'IQR';

  @override
  String get methodHint =>
      'Mean: all cycles · Median: robust · IQR: mean without outliers (1.5 × IQR)';

  @override
  String completeCycles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count complete cycles',
      one: '1 complete cycle',
    );
    return '$_temp0';
  }

  @override
  String incompleteCycles(int count) {
    return '$count incomplete';
  }

  @override
  String outliersRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outliers removed',
      one: '1 outlier removed',
    );
    return '$_temp0';
  }

  @override
  String get mean => 'Mean';

  @override
  String get median => 'Median';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Max';

  @override
  String get stdDev => 'Std. dev.';

  @override
  String get cv => 'CV';

  @override
  String get meanShort => 'Ø';

  @override
  String get medianShort => 'Md';

  @override
  String get specialTimesTotal => 'Special times';

  @override
  String get specialTimesExcluded => 'Not included in step or cycle times';

  @override
  String get noTimesShort => 'No times';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get design => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get general => 'General';

  @override
  String get defaultUnit => 'Default time unit';

  @override
  String get unitHm => 'HM (1/100 minute)';

  @override
  String get unitSeconds => 'Seconds';

  @override
  String get unitStopwatch => 'mm:ss.SSS';

  @override
  String get unitTmu => 'TMU (MTM)';

  @override
  String get defaultMethod => 'Real cycle time method';

  @override
  String get vibration => 'Vibration';

  @override
  String get hardwareKeys => 'Hardware keys';

  @override
  String get hardwareKeysHint =>
      'Volume up: next step (hold: special time) · Volume down: start/stop';

  @override
  String get holdThreshold => 'Hold time for special time';

  @override
  String get keepScreenOn => 'Keep screen on';

  @override
  String get keepScreenOnHint => 'Prevent screen lock while recording';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsHint =>
      'Show the running step while the app is in the background';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get holdToDictate => 'Hold to dictate';

  @override
  String get listening => 'Listening…';

  @override
  String get dictationUnavailable =>
      'Speech recognition is not available or microphone access was denied.';

  @override
  String get chooseVideo => 'Choose video';

  @override
  String get noVideoYet =>
      'Choose a recorded video to mark the steps during playback.';

  @override
  String get videoMissing =>
      'The video of this study can no longer be found. Please choose it again.';

  @override
  String get frameBack => 'Previous frame';

  @override
  String get frameForward => 'Next frame';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get undoMarker => 'Undo last marker';

  @override
  String get markStart => 'START';

  @override
  String get mark => 'STEP';

  @override
  String get markerBeforeLast =>
      'This position is before the last marker. Move the video forward first.';

  @override
  String get markerCannotMove =>
      'A marker cannot be moved past its neighbours.';

  @override
  String get tabTimes => 'Times';

  @override
  String get export => 'Export';

  @override
  String get exportCsv => 'CSV';

  @override
  String get exportCsvHint => 'All times as a table, opens in Excel';

  @override
  String get exportXlsx => 'Excel (.xlsx)';

  @override
  String get exportXlsxHint => 'Times, cycle matrix and analysis';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportStudy => 'Study';

  @override
  String get exportDescription => 'Description';

  @override
  String get studyNotes => 'Notes';

  @override
  String get studyNotesHint => 'e.g. workplace, shift, special conditions';

  @override
  String get exportDate => 'Exported';

  @override
  String get exportUnit => 'Unit';

  @override
  String get exportCycle => 'Cycle';

  @override
  String get exportLap => 'Lap';

  @override
  String get exportStepNo => 'Step no.';

  @override
  String get exportStep => 'Step';

  @override
  String get exportStart => 'Start';

  @override
  String get exportEnd => 'End';

  @override
  String get exportDuration => 'Duration';

  @override
  String get exportType => 'Type';

  @override
  String get exportNote => 'Note';

  @override
  String get exportStepTime => 'Step time';

  @override
  String get exportSheetTimes => 'Times';

  @override
  String get exportTotal => 'Total';

  @override
  String get exportComplete => 'Complete';

  @override
  String get exportYes => 'yes';

  @override
  String get exportNo => 'no';

  @override
  String get exportRealTime => 'Real time';

  @override
  String get exportShare => 'Share';

  @override
  String get exportOutliers => 'Outliers removed';

  @override
  String get exportPdf => 'PDF report';

  @override
  String get exportPdfHint => 'Printable analysis with key figures and cycles';

  @override
  String get reportTitle => 'Time study report';

  @override
  String get reportKeyFigures => 'Key figures';

  @override
  String reportPageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get reportNoData => 'No times recorded.';

  @override
  String get data => 'Data';

  @override
  String get createBackup => 'Create backup';

  @override
  String get createBackupHint =>
      'Save all studies to a file (videos are not included)';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get restoreBackupHint => 'Import studies from a backup file';

  @override
  String get restoreChoice =>
      'Add the studies from the file to your existing studies, or replace everything?';

  @override
  String get restoreMerge => 'Add';

  @override
  String get restoreReplace => 'Replace all';

  @override
  String get restoreReplaceWarning =>
      'All studies on this device will be deleted and replaced by the backup. This cannot be undone.';

  @override
  String restoreResult(int imported, int skipped) {
    return '$imported imported, $skipped already present.';
  }

  @override
  String get restoreVideoHint =>
      'Video studies: choose the video again on this device.';

  @override
  String get restoreInvalid =>
      'This is not a valid backup file. Nothing was changed.';

  @override
  String get restoreTooNew =>
      'This backup was created by a newer app version. Please update the app.';

  @override
  String newStepName(int number) {
    return 'Step $number';
  }

  @override
  String get resetZoom => 'Show the whole picture';

  @override
  String get cycleMark => 'CYCLE';

  @override
  String get closeCycle => 'Cycle complete';

  @override
  String get definingSteps =>
      'Every STEP marker adds a step. Tap CYCLE at the end of the cycle.';

  @override
  String get firstMarkerHint =>
      'Set the first marker where the first step begins';

  @override
  String get nameStepsTitle => 'Name the steps';

  @override
  String get useAsTimeStudy => 'Use steps for a live time study';

  @override
  String liveStudyName(String name) {
    return '$name (live)';
  }

  @override
  String get closeCycleRejected =>
      'The cycle can only be completed after the last marker, on the last step.';

  @override
  String get groups => 'Groups';

  @override
  String get emptyGroups => 'No groups yet';

  @override
  String get emptyGroupsHint =>
      'Groups collect studies, for example the machines of a production line, in a fixed order.';

  @override
  String get newGroup => 'New group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Delete the group \"$name\"? Its studies are kept without a group.';
  }

  @override
  String groupStudyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count studies',
      one: '1 study',
    );
    return '$_temp0';
  }

  @override
  String get emptyGroupStudies => 'No studies in this group yet';

  @override
  String get addStudies => 'Add studies';

  @override
  String get addNewStudy => 'Create a new study';

  @override
  String get addExistingStudies => 'Add existing studies';

  @override
  String get addExistingHint => 'Studies from other groups are moved here.';

  @override
  String get noStudiesToAdd => 'All studies are already in this group.';

  @override
  String get add => 'Add';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get moveToGroup => 'Move to group…';

  @override
  String get copyToGroup => 'Copy to group…';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get chooseGroup => 'Choose group';

  @override
  String get noGroup => 'No group';

  @override
  String copyName(String name) {
    return '$name (copy)';
  }

  @override
  String studyCopied(String name) {
    return 'Copy created: $name';
  }

  @override
  String get reorderHint => 'Drag the handle to change the order.';

  @override
  String get revisions => 'Revisions';

  @override
  String revisionCurrent(int number) {
    return 'Revision $number (current)';
  }

  @override
  String revisionTitle(int number) {
    return 'Revision $number';
  }

  @override
  String lastMeasured(String date) {
    return 'Last measurement: $date';
  }

  @override
  String measuredRange(String from, String to) {
    return 'Measured $from – $to';
  }

  @override
  String get newRevision => 'Start new measurement';

  @override
  String get newRevisionHint =>
      'Measure the study again (e.g. a year later). The current times are archived as a revision and stay available for comparison.';

  @override
  String newRevisionConfirm(int number) {
    return 'The current times are kept as revision $number for comparison. The study then starts empty with the same steps.';
  }

  @override
  String newRevisionStarted(int number) {
    return 'Revision $number started';
  }

  @override
  String get stopRecordingFirst => 'Stop the recording first.';

  @override
  String get noRevisions => 'No earlier revisions yet.';

  @override
  String get revisionThen => 'Then';

  @override
  String get revisionNow => 'Now';

  @override
  String get revisionDelta => 'Δ';

  @override
  String get deleteRevision => 'Delete revision';

  @override
  String deleteRevisionConfirm(int number) {
    return 'Delete revision $number with all its times?';
  }

  @override
  String removedStep(String name) {
    return '$name (removed)';
  }

  @override
  String get revisionNoTimes => 'No times recorded yet.';

  @override
  String staleTitle(int days) {
    return 'Measurement is $days days old';
  }

  @override
  String staleText(String name, String date, int number) {
    return 'The last time of \"$name\" was recorded on $date. Start a new measurement? The previous times are kept as revision $number for comparison.';
  }

  @override
  String get staleNewRevision => 'New measurement';

  @override
  String get staleContinue => 'Continue';

  @override
  String get staleDaysSetting => 'Suggest a new measurement';

  @override
  String staleDaysValue(int days) {
    return 'After $days days';
  }

  @override
  String get never => 'Never';

  @override
  String get groupReportTitle => 'Group report';

  @override
  String get reportOverview => 'Overview';

  @override
  String get exportGroup => 'Group';

  @override
  String get exportPosition => 'Pos.';

  @override
  String get exportCycles => 'Cycles';

  @override
  String get exportPreviousRevision => 'Previous revision';

  @override
  String get exportRevision => 'Revision';

  @override
  String get exportLastMeasured => 'Last measurement';

  @override
  String deviationFrom(int number) {
    return 'Deviation from revision $number';
  }

  @override
  String get exportGroupReport => 'Export group report';

  @override
  String get groupPdfHint => 'Overview and every study on its own pages';

  @override
  String get groupXlsxHint => 'Overview sheet and one sheet per study';

  @override
  String get lineAnalysis => 'Line analysis';

  @override
  String get lineTotalLabel => 'Sum of cycle times';

  @override
  String get lineCycleLabel => 'Line cycle time (bottleneck)';

  @override
  String get lineBottleneckLabel => 'Bottleneck';

  @override
  String get lineBalanceLabel => 'Line balance';

  @override
  String get lineOutputLabel => 'Output per hour';

  @override
  String get lineStations => 'Stations';

  @override
  String get lineChartHint =>
      'Stations in group order, stacked by step. The dashed line marks the bottleneck that paces the line.';

  @override
  String lineWaiting(String time) {
    return 'Waiting: $time';
  }

  @override
  String lineShare(String share) {
    return '$share of the line';
  }

  @override
  String get lineNotMeasured => 'No complete cycles';

  @override
  String lineVsPrevious(String delta) {
    return 'vs. previous revision: $delta';
  }

  @override
  String get reportContents => 'Contents';

  @override
  String get reportStation => 'Station';

  @override
  String get reportWaiting => 'Waiting';

  @override
  String get reportSheet => 'Sheet';

  @override
  String get reportBackToContents => 'Back to contents';

  @override
  String get reportStudies => 'Studies';

  @override
  String get groupFullPdf => 'PDF report (complete)';

  @override
  String get groupFullPdfHint =>
      'Cover with contents, line analysis, overview and all studies';

  @override
  String get groupFullXlsx => 'Excel (linked)';

  @override
  String get groupFullXlsxHint =>
      'Contents with links, line analysis with formulas, overview, one sheet per study';

  @override
  String get groupCompactPdf => 'PDF (compact)';

  @override
  String get groupCompactXlsx => 'Excel (compact)';

  @override
  String get addMachine => 'Machine with fixed cycle time';

  @override
  String get addMachineHint =>
      'Enter the average cycle time instead of measuring it';

  @override
  String get averageCycleTime => 'Average cycle time';

  @override
  String get invalidTime => 'Enter a time greater than 0';

  @override
  String get parallelToPrevious => 'Parallel to the one above';

  @override
  String get setCycleTime => 'Enter cycle time…';

  @override
  String get setCycleTimeHint =>
      'Replaces the times of this study. The previous times are kept as a revision.';

  @override
  String get lineLeadLabel => 'Lead time of one part';

  @override
  String lineParallelMachines(int count) {
    return '$count machines in parallel';
  }

  @override
  String get failureRisk => 'Failure risk';

  @override
  String get failureRiskHint =>
      'Output of the line while one machine is down. Parallel machines take over part of the work; a station with a single machine stops the whole line.';

  @override
  String singlePointsOfFailure(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count stations without a spare machine: each failure stops the line',
      one: '1 station without a spare machine: its failure stops the line',
    );
    return '$_temp0';
  }

  @override
  String outputDuringFailure(String output) {
    return 'Output during the failure: $output / h';
  }

  @override
  String get standstill => 'Standstill';

  @override
  String get noLoss => 'No loss';

  @override
  String get reportMachine => 'Machine';

  @override
  String get reportOutputDuring => 'Output during failure';

  @override
  String get reportLoss => 'Loss';

  @override
  String get addBuffer => 'Insert buffer before';

  @override
  String get editBuffer => 'Buffer';

  @override
  String get removeBuffer => 'Remove';

  @override
  String get bufferHint =>
      'Stores parts only when the next station is busy; otherwise they pass on the conveyor. Storing and retrieving take the buffer\'s own time.';

  @override
  String get bufferCapacity => 'Places';

  @override
  String get bufferStoreTime => 'Store time per part';

  @override
  String get bufferRetrieveTime => 'Retrieve time per part';

  @override
  String get invalidCount => 'Enter a whole number greater than 0';

  @override
  String bufferPlaces(int count) {
    return 'Buffer · $count places';
  }

  @override
  String bufferTimes(String store, String retrieve) {
    return 'In $store · out $retrieve';
  }

  @override
  String get shiftLength => 'Shift length';

  @override
  String get failureDuration => 'Assumed failure duration';

  @override
  String get simulation => 'Simulation';

  @override
  String get simulationHint =>
      'Plays the line through with the real cycle times: parallel machines share the work, a part waits when the next station is busy, buffers store parts on a jam and empty themselves again.';

  @override
  String get simulationPeriod => 'Period';

  @override
  String get shift => 'Shift';

  @override
  String get custom => 'Custom';

  @override
  String get hoursLabel => 'Hours';

  @override
  String get simulationFailure => 'Failure';

  @override
  String get noFailure => 'No failure';

  @override
  String get failureStart => 'Start after [h]';

  @override
  String get failureStartHint => 'default: after a quarter';

  @override
  String get failureDurationMinutes => 'Duration [min]';

  @override
  String get runSimulation => 'Simulate';

  @override
  String get simPartsNormal => 'Parts without failure';

  @override
  String get simPartsFailure => 'Parts with failure';

  @override
  String get simLost => 'Lost parts';

  @override
  String get simLostWithoutBuffers => 'Lost without buffers';

  @override
  String buffersSave(int count) {
    return 'The buffers save $count parts.';
  }

  @override
  String bufferMaxLevel(int max, int end) {
    return 'Max. fill $max, at the end $end';
  }

  @override
  String bufferMoves(int stores, int retrieves) {
    return 'Stored $stores ×, retrieved $retrieves ×';
  }

  @override
  String bufferHandling(String time) {
    return 'Handling time $time';
  }

  @override
  String simUtilization(String value) {
    return 'Utilization $value';
  }

  @override
  String simBlocked(String time) {
    return 'blocked $time';
  }

  @override
  String simDown(String time) {
    return 'down $time';
  }
}
