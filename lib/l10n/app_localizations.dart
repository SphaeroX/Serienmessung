import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CycleScope'**
  String get appTitle;

  /// No description provided for @createStudy.
  ///
  /// In en, this message translates to:
  /// **'Create study'**
  String get createStudy;

  /// No description provided for @newStudyTitle.
  ///
  /// In en, this message translates to:
  /// **'New study'**
  String get newStudyTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionLabel;

  /// No description provided for @modeSection.
  ///
  /// In en, this message translates to:
  /// **'Study mode'**
  String get modeSection;

  /// No description provided for @modeSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get modeSimple;

  /// No description provided for @modeSimpleDesc.
  ///
  /// In en, this message translates to:
  /// **'Standard stopwatch with laps'**
  String get modeSimpleDesc;

  /// No description provided for @modeSimpleInfo.
  ///
  /// In en, this message translates to:
  /// **'A classic stopwatch. Every lap press closes the current lap and starts the next one. No steps needed.'**
  String get modeSimpleInfo;

  /// No description provided for @modeTimeStudy.
  ///
  /// In en, this message translates to:
  /// **'Time study'**
  String get modeTimeStudy;

  /// No description provided for @modeTimeStudyDesc.
  ///
  /// In en, this message translates to:
  /// **'Fixed sequence of defined steps'**
  String get modeTimeStudyDesc;

  /// No description provided for @modeTimeStudyInfo.
  ///
  /// In en, this message translates to:
  /// **'You define a fixed sequence of steps. Step 1 is active as soon as you start. Each press moves to the next step; after the last step a new cycle begins with step 1. Ideal for repetitive, ordered work.'**
  String get modeTimeStudyInfo;

  /// No description provided for @modeStepTimer.
  ///
  /// In en, this message translates to:
  /// **'Step timer'**
  String get modeStepTimer;

  /// No description provided for @modeStepTimerDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap steps in any order, time per step'**
  String get modeStepTimerDesc;

  /// No description provided for @modeStepTimerInfo.
  ///
  /// In en, this message translates to:
  /// **'Tap any step to start timing it. The time always runs for the step you tapped last. Useful when the order of work varies.'**
  String get modeStepTimerInfo;

  /// No description provided for @modeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video study'**
  String get modeVideo;

  /// No description provided for @modeVideoDesc.
  ///
  /// In en, this message translates to:
  /// **'Import a video and define the steps while marking it'**
  String get modeVideoDesc;

  /// No description provided for @modeVideoInfo.
  ///
  /// In en, this message translates to:
  /// **'Import a recorded video and play it back. No steps are needed beforehand: in the first cycle every marker starts a new step. Tap “Cycle complete” at the end of the cycle and name the steps. Further markers then follow these steps cycle by cycle. Afterwards you can use the steps for a live time study.'**
  String get modeVideoInfo;

  /// No description provided for @modeBadgeSimple.
  ///
  /// In en, this message translates to:
  /// **'SIMPLE'**
  String get modeBadgeSimple;

  /// No description provided for @modeBadgeTimeStudy.
  ///
  /// In en, this message translates to:
  /// **'TIME STUDY'**
  String get modeBadgeTimeStudy;

  /// No description provided for @modeBadgeStepTimer.
  ///
  /// In en, this message translates to:
  /// **'STEP TIMER'**
  String get modeBadgeStepTimer;

  /// No description provided for @modeBadgeVideo.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get modeBadgeVideo;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @stepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps (one per line)'**
  String get stepsLabel;

  /// No description provided for @stepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String stepsCount(int count);

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @stepsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least one step'**
  String get stepsRequired;

  /// No description provided for @defaultStudyName.
  ///
  /// In en, this message translates to:
  /// **'Time study #{number}'**
  String defaultStudyName(String number);

  /// No description provided for @emptyStudies.
  ///
  /// In en, this message translates to:
  /// **'No studies yet. Create your first time study.'**
  String get emptyStudies;

  /// No description provided for @createdLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdLabel;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @cyclesLabel.
  ///
  /// In en, this message translates to:
  /// **'CYCLES'**
  String get cyclesLabel;

  /// No description provided for @lapsLabel.
  ///
  /// In en, this message translates to:
  /// **'LAPS'**
  String get lapsLabel;

  /// No description provided for @measurementsLabel.
  ///
  /// In en, this message translates to:
  /// **'TIMES'**
  String get measurementsLabel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteStudy.
  ///
  /// In en, this message translates to:
  /// **'Delete study'**
  String get deleteStudy;

  /// No description provided for @deleteStudyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" including all measurements?'**
  String deleteStudyConfirm(String name);

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalLabel;

  /// No description provided for @stepLabel.
  ///
  /// In en, this message translates to:
  /// **'STEP'**
  String get stepLabel;

  /// No description provided for @lapLabel.
  ///
  /// In en, this message translates to:
  /// **'LAP'**
  String get lapLabel;

  /// No description provided for @lapNumber.
  ///
  /// In en, this message translates to:
  /// **'Lap {number}'**
  String lapNumber(int number);

  /// No description provided for @cycleNumber.
  ///
  /// In en, this message translates to:
  /// **'Cycle {number}'**
  String cycleNumber(int number);

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {index} of {count}'**
  String stepOf(int index, int count);

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next: {name}'**
  String nextStep(String name);

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'RECORDING'**
  String get recording;

  /// No description provided for @specialTimeRunning.
  ///
  /// In en, this message translates to:
  /// **'SPECIAL TIME'**
  String get specialTimeRunning;

  /// No description provided for @specialTime.
  ///
  /// In en, this message translates to:
  /// **'Special time'**
  String get specialTime;

  /// No description provided for @noTimesYet.
  ///
  /// In en, this message translates to:
  /// **'No times yet. Press start – step 1 begins immediately.'**
  String get noTimesYet;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get stop;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get resume;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'LAP'**
  String get lap;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop recording and discard the unfinished step?'**
  String get resetConfirm;

  /// No description provided for @specialShort.
  ///
  /// In en, this message translates to:
  /// **'HOLD\nSPECIAL'**
  String get specialShort;

  /// No description provided for @specialTimeNote.
  ///
  /// In en, this message translates to:
  /// **'Special time note'**
  String get specialTimeNote;

  /// No description provided for @specialTimeNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get specialTimeNoteHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @rebootInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The device was restarted during the recording. Completed times are kept; the unfinished step was discarded.'**
  String get rebootInterrupted;

  /// No description provided for @recordingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress'**
  String get recordingInProgress;

  /// No description provided for @recordingInProgressText.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is still being recorded. Continue?'**
  String recordingInProgressText(String name);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @recBadge.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get recBadge;

  /// No description provided for @tabLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get tabLive;

  /// No description provided for @replaceVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace video?'**
  String get replaceVideoTitle;

  /// No description provided for @replaceVideoBody.
  ///
  /// In en, this message translates to:
  /// **'The recorded cycles belong to the current video. Delete them or keep them?'**
  String get replaceVideoBody;

  /// No description provided for @keepCycles.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepCycles;

  /// No description provided for @deleteCycles.
  ///
  /// In en, this message translates to:
  /// **'Delete cycles'**
  String get deleteCycles;

  /// No description provided for @tabMark.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get tabMark;

  /// No description provided for @tabCycles.
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get tabCycles;

  /// No description provided for @tabLaps.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get tabLaps;

  /// No description provided for @incomplete.
  ///
  /// In en, this message translates to:
  /// **'incomplete'**
  String get incomplete;

  /// No description provided for @deleteCycle.
  ///
  /// In en, this message translates to:
  /// **'Delete cycle'**
  String get deleteCycle;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @deletedTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 time deleted} other{{count} times deleted}}'**
  String deletedTimes(int count);

  /// No description provided for @editStudy.
  ///
  /// In en, this message translates to:
  /// **'Edit study'**
  String get editStudy;

  /// No description provided for @renameStep.
  ///
  /// In en, this message translates to:
  /// **'Rename step'**
  String get renameStep;

  /// No description provided for @deleteStep.
  ///
  /// In en, this message translates to:
  /// **'Delete step'**
  String get deleteStep;

  /// No description provided for @deleteStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete step \"{name}\"?'**
  String deleteStepConfirm(String name);

  /// No description provided for @deleteStepWithTimes.
  ///
  /// In en, this message translates to:
  /// **'Delete step \"{name}\" including {count, plural, =1{1 recorded time} other{{count} recorded times}}?'**
  String deleteStepWithTimes(String name, int count);

  /// No description provided for @stepsSection.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get stepsSection;

  /// No description provided for @stepsEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to rename, drag to reorder. Recorded times stay with their step.'**
  String get stepsEditHint;

  /// No description provided for @newStepHint.
  ///
  /// In en, this message translates to:
  /// **'New step'**
  String get newStepHint;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get addStep;

  /// No description provided for @tabAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get tabAnalysis;

  /// No description provided for @realCycleTime.
  ///
  /// In en, this message translates to:
  /// **'Real cycle time'**
  String get realCycleTime;

  /// No description provided for @realLapTime.
  ///
  /// In en, this message translates to:
  /// **'Real lap time'**
  String get realLapTime;

  /// No description provided for @methodMean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get methodMean;

  /// No description provided for @methodMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get methodMedian;

  /// No description provided for @methodIqr.
  ///
  /// In en, this message translates to:
  /// **'IQR'**
  String get methodIqr;

  /// No description provided for @methodHint.
  ///
  /// In en, this message translates to:
  /// **'Mean: all cycles · Median: robust · IQR: mean without outliers (1.5 × IQR)'**
  String get methodHint;

  /// No description provided for @completeCycles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 complete cycle} other{{count} complete cycles}}'**
  String completeCycles(int count);

  /// No description provided for @incompleteCycles.
  ///
  /// In en, this message translates to:
  /// **'{count} incomplete'**
  String incompleteCycles(int count);

  /// No description provided for @outliersRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 outlier removed} other{{count} outliers removed}}'**
  String outliersRemoved(int count);

  /// No description provided for @mean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get mean;

  /// No description provided for @median.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get median;

  /// No description provided for @minimum.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minimum;

  /// No description provided for @maximum.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maximum;

  /// No description provided for @stdDev.
  ///
  /// In en, this message translates to:
  /// **'Std. dev.'**
  String get stdDev;

  /// No description provided for @cv.
  ///
  /// In en, this message translates to:
  /// **'CV'**
  String get cv;

  /// No description provided for @meanShort.
  ///
  /// In en, this message translates to:
  /// **'Ø'**
  String get meanShort;

  /// No description provided for @medianShort.
  ///
  /// In en, this message translates to:
  /// **'Md'**
  String get medianShort;

  /// No description provided for @specialTimesTotal.
  ///
  /// In en, this message translates to:
  /// **'Special times'**
  String get specialTimesTotal;

  /// No description provided for @specialTimesExcluded.
  ///
  /// In en, this message translates to:
  /// **'Not included in step or cycle times'**
  String get specialTimesExcluded;

  /// No description provided for @noTimesShort.
  ///
  /// In en, this message translates to:
  /// **'No times'**
  String get noTimesShort;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @design.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get design;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get followSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @defaultUnit.
  ///
  /// In en, this message translates to:
  /// **'Default time unit'**
  String get defaultUnit;

  /// No description provided for @unitHm.
  ///
  /// In en, this message translates to:
  /// **'HM (1/100 minute)'**
  String get unitHm;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get unitSeconds;

  /// No description provided for @unitStopwatch.
  ///
  /// In en, this message translates to:
  /// **'mm:ss.SSS'**
  String get unitStopwatch;

  /// No description provided for @unitTmu.
  ///
  /// In en, this message translates to:
  /// **'TMU (MTM)'**
  String get unitTmu;

  /// No description provided for @defaultMethod.
  ///
  /// In en, this message translates to:
  /// **'Real cycle time method'**
  String get defaultMethod;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @hardwareKeys.
  ///
  /// In en, this message translates to:
  /// **'Hardware keys'**
  String get hardwareKeys;

  /// No description provided for @hardwareKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Volume up: next step (hold: special time) · Volume down: start/stop'**
  String get hardwareKeysHint;

  /// No description provided for @holdThreshold.
  ///
  /// In en, this message translates to:
  /// **'Hold time for special time'**
  String get holdThreshold;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnHint.
  ///
  /// In en, this message translates to:
  /// **'Prevent screen lock while recording'**
  String get keepScreenOnHint;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Show the running step while the app is in the background'**
  String get notificationsHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @holdToDictate.
  ///
  /// In en, this message translates to:
  /// **'Hold to dictate'**
  String get holdToDictate;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @dictationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available or microphone access was denied.'**
  String get dictationUnavailable;

  /// No description provided for @chooseVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose video'**
  String get chooseVideo;

  /// No description provided for @noVideoYet.
  ///
  /// In en, this message translates to:
  /// **'Choose a recorded video to mark the steps during playback.'**
  String get noVideoYet;

  /// No description provided for @videoMissing.
  ///
  /// In en, this message translates to:
  /// **'The video of this study can no longer be found. Please choose it again.'**
  String get videoMissing;

  /// No description provided for @frameBack.
  ///
  /// In en, this message translates to:
  /// **'Previous frame'**
  String get frameBack;

  /// No description provided for @frameForward.
  ///
  /// In en, this message translates to:
  /// **'Next frame'**
  String get frameForward;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @undoMarker.
  ///
  /// In en, this message translates to:
  /// **'Undo last marker'**
  String get undoMarker;

  /// No description provided for @markStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get markStart;

  /// No description provided for @mark.
  ///
  /// In en, this message translates to:
  /// **'STEP'**
  String get mark;

  /// No description provided for @markerBeforeLast.
  ///
  /// In en, this message translates to:
  /// **'This position is before the last marker. Move the video forward first.'**
  String get markerBeforeLast;

  /// No description provided for @markerCannotMove.
  ///
  /// In en, this message translates to:
  /// **'A marker cannot be moved past its neighbours.'**
  String get markerCannotMove;

  /// No description provided for @tabTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get tabTimes;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvHint.
  ///
  /// In en, this message translates to:
  /// **'All times as a table, opens in Excel'**
  String get exportCsvHint;

  /// No description provided for @exportXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (.xlsx)'**
  String get exportXlsx;

  /// No description provided for @exportXlsxHint.
  ///
  /// In en, this message translates to:
  /// **'Times, cycle matrix and analysis'**
  String get exportXlsxHint;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get exportStudy;

  /// No description provided for @exportDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get exportDescription;

  /// No description provided for @studyNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get studyNotes;

  /// No description provided for @studyNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. workplace, shift, special conditions'**
  String get studyNotesHint;

  /// No description provided for @exportDate.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exportDate;

  /// No description provided for @exportUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get exportUnit;

  /// No description provided for @exportCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get exportCycle;

  /// No description provided for @exportLap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get exportLap;

  /// No description provided for @exportStepNo.
  ///
  /// In en, this message translates to:
  /// **'Step no.'**
  String get exportStepNo;

  /// No description provided for @exportStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get exportStep;

  /// No description provided for @exportStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get exportStart;

  /// No description provided for @exportEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get exportEnd;

  /// No description provided for @exportDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get exportDuration;

  /// No description provided for @exportType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get exportType;

  /// No description provided for @exportNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exportNote;

  /// No description provided for @exportStepTime.
  ///
  /// In en, this message translates to:
  /// **'Step time'**
  String get exportStepTime;

  /// No description provided for @exportSheetTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get exportSheetTimes;

  /// No description provided for @exportTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get exportTotal;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get exportComplete;

  /// No description provided for @exportYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get exportYes;

  /// No description provided for @exportNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get exportNo;

  /// No description provided for @exportRealTime.
  ///
  /// In en, this message translates to:
  /// **'Real time'**
  String get exportRealTime;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exportShare;

  /// No description provided for @exportOutliers.
  ///
  /// In en, this message translates to:
  /// **'Outliers removed'**
  String get exportOutliers;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF report'**
  String get exportPdf;

  /// No description provided for @exportPdfHint.
  ///
  /// In en, this message translates to:
  /// **'Printable analysis with key figures and cycles'**
  String get exportPdfHint;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Time study report'**
  String get reportTitle;

  /// No description provided for @reportKeyFigures.
  ///
  /// In en, this message translates to:
  /// **'Key figures'**
  String get reportKeyFigures;

  /// No description provided for @reportPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String reportPageOf(int page, int pages);

  /// No description provided for @reportNoData.
  ///
  /// In en, this message translates to:
  /// **'No times recorded.'**
  String get reportNoData;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @createBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Save all studies to a file (videos are not included)'**
  String get createBackupHint;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Import studies from a backup file'**
  String get restoreBackupHint;

  /// No description provided for @restoreChoice.
  ///
  /// In en, this message translates to:
  /// **'Add the studies from the file to your existing studies, or replace everything?'**
  String get restoreChoice;

  /// No description provided for @restoreMerge.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get restoreMerge;

  /// No description provided for @restoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get restoreReplace;

  /// No description provided for @restoreReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'All studies on this device will be deleted and replaced by the backup. This cannot be undone.'**
  String get restoreReplaceWarning;

  /// No description provided for @restoreResult.
  ///
  /// In en, this message translates to:
  /// **'{imported} imported, {skipped} already present.'**
  String restoreResult(int imported, int skipped);

  /// No description provided for @restoreVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Video studies: choose the video again on this device.'**
  String get restoreVideoHint;

  /// No description provided for @restoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid backup file. Nothing was changed.'**
  String get restoreInvalid;

  /// No description provided for @restoreTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer app version. Please update the app.'**
  String get restoreTooNew;

  /// No description provided for @newStepName.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String newStepName(int number);

  /// No description provided for @resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Show the whole picture'**
  String get resetZoom;

  /// No description provided for @cycleMark.
  ///
  /// In en, this message translates to:
  /// **'CYCLE'**
  String get cycleMark;

  /// No description provided for @closeCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle complete'**
  String get closeCycle;

  /// No description provided for @definingSteps.
  ///
  /// In en, this message translates to:
  /// **'Every STEP marker adds a step. Tap CYCLE at the end of the cycle.'**
  String get definingSteps;

  /// No description provided for @firstMarkerHint.
  ///
  /// In en, this message translates to:
  /// **'Set the first marker where the first step begins'**
  String get firstMarkerHint;

  /// No description provided for @nameStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Name the steps'**
  String get nameStepsTitle;

  /// No description provided for @useAsTimeStudy.
  ///
  /// In en, this message translates to:
  /// **'Use steps for a live time study'**
  String get useAsTimeStudy;

  /// No description provided for @liveStudyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (live)'**
  String liveStudyName(String name);

  /// No description provided for @closeCycleRejected.
  ///
  /// In en, this message translates to:
  /// **'The cycle can only be completed after the last marker, on the last step.'**
  String get closeCycleRejected;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @emptyGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get emptyGroups;

  /// No description provided for @emptyGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Groups collect studies, for example the machines of a production line, in a fixed order.'**
  String get emptyGroupsHint;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the group \"{name}\"? Its studies are kept without a group.'**
  String deleteGroupConfirm(String name);

  /// No description provided for @groupStudyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 study} other{{count} studies}}'**
  String groupStudyCount(int count);

  /// No description provided for @emptyGroupStudies.
  ///
  /// In en, this message translates to:
  /// **'No studies in this group yet'**
  String get emptyGroupStudies;

  /// No description provided for @addStudies.
  ///
  /// In en, this message translates to:
  /// **'Add studies'**
  String get addStudies;

  /// No description provided for @addNewStudy.
  ///
  /// In en, this message translates to:
  /// **'Create a new study'**
  String get addNewStudy;

  /// No description provided for @addExistingStudies.
  ///
  /// In en, this message translates to:
  /// **'Add existing studies'**
  String get addExistingStudies;

  /// No description provided for @addExistingHint.
  ///
  /// In en, this message translates to:
  /// **'Studies from other groups are moved here.'**
  String get addExistingHint;

  /// No description provided for @noStudiesToAdd.
  ///
  /// In en, this message translates to:
  /// **'All studies are already in this group.'**
  String get noStudiesToAdd;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group…'**
  String get moveToGroup;

  /// No description provided for @copyToGroup.
  ///
  /// In en, this message translates to:
  /// **'Copy to group…'**
  String get copyToGroup;

  /// No description provided for @removeFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroup;

  /// No description provided for @chooseGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose group'**
  String get chooseGroup;

  /// No description provided for @noGroup.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get noGroup;

  /// No description provided for @copyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String copyName(String name);

  /// No description provided for @studyCopied.
  ///
  /// In en, this message translates to:
  /// **'Copy created: {name}'**
  String studyCopied(String name);

  /// No description provided for @reorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handle to change the order.'**
  String get reorderHint;

  /// No description provided for @revisions.
  ///
  /// In en, this message translates to:
  /// **'Revisions'**
  String get revisions;

  /// No description provided for @revisionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Revision {number} (current)'**
  String revisionCurrent(int number);

  /// No description provided for @revisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Revision {number}'**
  String revisionTitle(int number);

  /// No description provided for @lastMeasured.
  ///
  /// In en, this message translates to:
  /// **'Last measurement: {date}'**
  String lastMeasured(String date);

  /// No description provided for @measuredRange.
  ///
  /// In en, this message translates to:
  /// **'Measured {from} – {to}'**
  String measuredRange(String from, String to);

  /// No description provided for @newRevision.
  ///
  /// In en, this message translates to:
  /// **'Start new measurement'**
  String get newRevision;

  /// No description provided for @newRevisionHint.
  ///
  /// In en, this message translates to:
  /// **'Measure the study again (e.g. a year later). The current times are archived as a revision and stay available for comparison.'**
  String get newRevisionHint;

  /// No description provided for @newRevisionConfirm.
  ///
  /// In en, this message translates to:
  /// **'The current times are kept as revision {number} for comparison. The study then starts empty with the same steps.'**
  String newRevisionConfirm(int number);

  /// No description provided for @newRevisionStarted.
  ///
  /// In en, this message translates to:
  /// **'Revision {number} started'**
  String newRevisionStarted(int number);

  /// No description provided for @stopRecordingFirst.
  ///
  /// In en, this message translates to:
  /// **'Stop the recording first.'**
  String get stopRecordingFirst;

  /// No description provided for @noRevisions.
  ///
  /// In en, this message translates to:
  /// **'No earlier revisions yet.'**
  String get noRevisions;

  /// No description provided for @revisionThen.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get revisionThen;

  /// No description provided for @revisionNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get revisionNow;

  /// No description provided for @revisionDelta.
  ///
  /// In en, this message translates to:
  /// **'Δ'**
  String get revisionDelta;

  /// No description provided for @deleteRevision.
  ///
  /// In en, this message translates to:
  /// **'Delete revision'**
  String get deleteRevision;

  /// No description provided for @deleteRevisionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete revision {number} with all its times?'**
  String deleteRevisionConfirm(int number);

  /// No description provided for @removedStep.
  ///
  /// In en, this message translates to:
  /// **'{name} (removed)'**
  String removedStep(String name);

  /// No description provided for @revisionNoTimes.
  ///
  /// In en, this message translates to:
  /// **'No times recorded yet.'**
  String get revisionNoTimes;

  /// No description provided for @staleTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement is {days} days old'**
  String staleTitle(int days);

  /// No description provided for @staleText.
  ///
  /// In en, this message translates to:
  /// **'The last time of \"{name}\" was recorded on {date}. Start a new measurement? The previous times are kept as revision {number} for comparison.'**
  String staleText(String name, String date, int number);

  /// No description provided for @staleNewRevision.
  ///
  /// In en, this message translates to:
  /// **'New measurement'**
  String get staleNewRevision;

  /// No description provided for @staleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get staleContinue;

  /// No description provided for @staleDaysSetting.
  ///
  /// In en, this message translates to:
  /// **'Suggest a new measurement'**
  String get staleDaysSetting;

  /// No description provided for @staleDaysValue.
  ///
  /// In en, this message translates to:
  /// **'After {days} days'**
  String staleDaysValue(int days);

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @groupReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Group report'**
  String get groupReportTitle;

  /// No description provided for @reportOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get reportOverview;

  /// No description provided for @exportGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get exportGroup;

  /// No description provided for @exportPosition.
  ///
  /// In en, this message translates to:
  /// **'Pos.'**
  String get exportPosition;

  /// No description provided for @exportCycles.
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get exportCycles;

  /// No description provided for @exportPreviousRevision.
  ///
  /// In en, this message translates to:
  /// **'Previous revision'**
  String get exportPreviousRevision;

  /// No description provided for @exportRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get exportRevision;

  /// No description provided for @exportLastMeasured.
  ///
  /// In en, this message translates to:
  /// **'Last measurement'**
  String get exportLastMeasured;

  /// No description provided for @deviationFrom.
  ///
  /// In en, this message translates to:
  /// **'Deviation from revision {number}'**
  String deviationFrom(int number);

  /// No description provided for @exportGroupReport.
  ///
  /// In en, this message translates to:
  /// **'Export group report'**
  String get exportGroupReport;

  /// No description provided for @groupPdfHint.
  ///
  /// In en, this message translates to:
  /// **'Overview and every study on its own pages'**
  String get groupPdfHint;

  /// No description provided for @groupXlsxHint.
  ///
  /// In en, this message translates to:
  /// **'Overview sheet and one sheet per study'**
  String get groupXlsxHint;

  /// No description provided for @lineAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Line analysis'**
  String get lineAnalysis;

  /// No description provided for @lineTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Sum of cycle times'**
  String get lineTotalLabel;

  /// No description provided for @lineCycleLabel.
  ///
  /// In en, this message translates to:
  /// **'Line cycle time (bottleneck)'**
  String get lineCycleLabel;

  /// No description provided for @lineBottleneckLabel.
  ///
  /// In en, this message translates to:
  /// **'Bottleneck'**
  String get lineBottleneckLabel;

  /// No description provided for @lineBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Line balance'**
  String get lineBalanceLabel;

  /// No description provided for @lineOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output per hour'**
  String get lineOutputLabel;

  /// No description provided for @lineStations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get lineStations;

  /// No description provided for @lineChartHint.
  ///
  /// In en, this message translates to:
  /// **'Stations in group order, stacked by step. The dashed line marks the bottleneck that paces the line.'**
  String get lineChartHint;

  /// No description provided for @lineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting: {time}'**
  String lineWaiting(String time);

  /// No description provided for @lineShare.
  ///
  /// In en, this message translates to:
  /// **'{share} of the line'**
  String lineShare(String share);

  /// No description provided for @lineNotMeasured.
  ///
  /// In en, this message translates to:
  /// **'No complete cycles'**
  String get lineNotMeasured;

  /// No description provided for @lineVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'vs. previous revision: {delta}'**
  String lineVsPrevious(String delta);

  /// No description provided for @reportContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get reportContents;

  /// No description provided for @reportStation.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get reportStation;

  /// No description provided for @reportWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get reportWaiting;

  /// No description provided for @reportSheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get reportSheet;

  /// No description provided for @reportBackToContents.
  ///
  /// In en, this message translates to:
  /// **'Back to contents'**
  String get reportBackToContents;

  /// No description provided for @reportStudies.
  ///
  /// In en, this message translates to:
  /// **'Studies'**
  String get reportStudies;

  /// No description provided for @groupFullPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF report (complete)'**
  String get groupFullPdf;

  /// No description provided for @groupFullPdfHint.
  ///
  /// In en, this message translates to:
  /// **'Cover with contents, line analysis, overview and all studies'**
  String get groupFullPdfHint;

  /// No description provided for @groupFullXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (linked)'**
  String get groupFullXlsx;

  /// No description provided for @groupFullXlsxHint.
  ///
  /// In en, this message translates to:
  /// **'Contents with links, line analysis with formulas, overview, one sheet per study'**
  String get groupFullXlsxHint;

  /// No description provided for @groupCompactPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF (compact)'**
  String get groupCompactPdf;

  /// No description provided for @groupCompactXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (compact)'**
  String get groupCompactXlsx;

  /// No description provided for @addMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine with fixed cycle time'**
  String get addMachine;

  /// No description provided for @addMachineHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the average cycle time instead of measuring it'**
  String get addMachineHint;

  /// No description provided for @averageCycleTime.
  ///
  /// In en, this message translates to:
  /// **'Average cycle time'**
  String get averageCycleTime;

  /// No description provided for @invalidTime.
  ///
  /// In en, this message translates to:
  /// **'Enter a time greater than 0'**
  String get invalidTime;

  /// No description provided for @parallelToPrevious.
  ///
  /// In en, this message translates to:
  /// **'Parallel to the one above'**
  String get parallelToPrevious;

  /// No description provided for @setCycleTime.
  ///
  /// In en, this message translates to:
  /// **'Enter cycle time…'**
  String get setCycleTime;

  /// No description provided for @setCycleTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces the times of this study. The previous times are kept as a revision.'**
  String get setCycleTimeHint;

  /// No description provided for @lineLeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Lead time of one part'**
  String get lineLeadLabel;

  /// No description provided for @lineParallelMachines.
  ///
  /// In en, this message translates to:
  /// **'{count} machines in parallel'**
  String lineParallelMachines(int count);

  /// No description provided for @failureRisk.
  ///
  /// In en, this message translates to:
  /// **'Failure risk'**
  String get failureRisk;

  /// No description provided for @failureRiskHint.
  ///
  /// In en, this message translates to:
  /// **'Output of the line while one machine is down. Parallel machines take over part of the work; a station with a single machine stops the whole line.'**
  String get failureRiskHint;

  /// No description provided for @singlePointsOfFailure.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 station without a spare machine: its failure stops the line} other{{count} stations without a spare machine: each failure stops the line}}'**
  String singlePointsOfFailure(int count);

  /// No description provided for @outputDuringFailure.
  ///
  /// In en, this message translates to:
  /// **'Output during the failure: {output} / h'**
  String outputDuringFailure(String output);

  /// No description provided for @standstill.
  ///
  /// In en, this message translates to:
  /// **'Standstill'**
  String get standstill;

  /// No description provided for @noLoss.
  ///
  /// In en, this message translates to:
  /// **'No loss'**
  String get noLoss;

  /// No description provided for @reportMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get reportMachine;

  /// No description provided for @reportOutputDuring.
  ///
  /// In en, this message translates to:
  /// **'Output during failure'**
  String get reportOutputDuring;

  /// No description provided for @reportLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get reportLoss;

  /// No description provided for @addBuffer.
  ///
  /// In en, this message translates to:
  /// **'Insert buffer before'**
  String get addBuffer;

  /// No description provided for @editBuffer.
  ///
  /// In en, this message translates to:
  /// **'Buffer'**
  String get editBuffer;

  /// No description provided for @removeBuffer.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeBuffer;

  /// No description provided for @bufferHint.
  ///
  /// In en, this message translates to:
  /// **'Stores parts only when the next station is busy; otherwise they pass on the conveyor. Storing and retrieving take the buffer\'s own time.'**
  String get bufferHint;

  /// No description provided for @bufferCapacity.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get bufferCapacity;

  /// No description provided for @bufferStoreTime.
  ///
  /// In en, this message translates to:
  /// **'Store time per part'**
  String get bufferStoreTime;

  /// No description provided for @bufferRetrieveTime.
  ///
  /// In en, this message translates to:
  /// **'Retrieve time per part'**
  String get bufferRetrieveTime;

  /// No description provided for @invalidCount.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than 0'**
  String get invalidCount;

  /// No description provided for @bufferPlaces.
  ///
  /// In en, this message translates to:
  /// **'Buffer · {count} places'**
  String bufferPlaces(int count);

  /// No description provided for @bufferTimes.
  ///
  /// In en, this message translates to:
  /// **'In {store} · out {retrieve}'**
  String bufferTimes(String store, String retrieve);

  /// No description provided for @shiftLength.
  ///
  /// In en, this message translates to:
  /// **'Shift length'**
  String get shiftLength;

  /// No description provided for @failureDuration.
  ///
  /// In en, this message translates to:
  /// **'Assumed failure duration'**
  String get failureDuration;

  /// No description provided for @simulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get simulation;

  /// No description provided for @simulationHint.
  ///
  /// In en, this message translates to:
  /// **'Plays the line through with the real cycle times: parallel machines share the work, a part waits when the next station is busy, buffers store parts on a jam and empty themselves again.'**
  String get simulationHint;

  /// No description provided for @simulationPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get simulationPeriod;

  /// No description provided for @shift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shift;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @simulationFailure.
  ///
  /// In en, this message translates to:
  /// **'Failure'**
  String get simulationFailure;

  /// No description provided for @noFailure.
  ///
  /// In en, this message translates to:
  /// **'No failure'**
  String get noFailure;

  /// No description provided for @failureStart.
  ///
  /// In en, this message translates to:
  /// **'Start after [h]'**
  String get failureStart;

  /// No description provided for @failureStartHint.
  ///
  /// In en, this message translates to:
  /// **'default: after a quarter'**
  String get failureStartHint;

  /// No description provided for @failureDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration [min]'**
  String get failureDurationMinutes;

  /// No description provided for @runSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get runSimulation;

  /// No description provided for @simPartsNormal.
  ///
  /// In en, this message translates to:
  /// **'Parts without failure'**
  String get simPartsNormal;

  /// No description provided for @simPartsFailure.
  ///
  /// In en, this message translates to:
  /// **'Parts with failure'**
  String get simPartsFailure;

  /// No description provided for @simLost.
  ///
  /// In en, this message translates to:
  /// **'Lost parts'**
  String get simLost;

  /// No description provided for @simLostWithoutBuffers.
  ///
  /// In en, this message translates to:
  /// **'Lost without buffers'**
  String get simLostWithoutBuffers;

  /// No description provided for @buffersSave.
  ///
  /// In en, this message translates to:
  /// **'The buffers save {count} parts.'**
  String buffersSave(int count);

  /// No description provided for @bufferMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'Max. fill {max}, at the end {end}'**
  String bufferMaxLevel(int max, int end);

  /// No description provided for @bufferMoves.
  ///
  /// In en, this message translates to:
  /// **'Stored {stores} ×, retrieved {retrieves} ×'**
  String bufferMoves(int stores, int retrieves);

  /// No description provided for @bufferHandling.
  ///
  /// In en, this message translates to:
  /// **'Handling time {time}'**
  String bufferHandling(String time);

  /// No description provided for @simUtilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization {value}'**
  String simUtilization(String value);

  /// No description provided for @simBlocked.
  ///
  /// In en, this message translates to:
  /// **'blocked {time}'**
  String simBlocked(String time);

  /// No description provided for @simDown.
  ///
  /// In en, this message translates to:
  /// **'down {time}'**
  String simDown(String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
