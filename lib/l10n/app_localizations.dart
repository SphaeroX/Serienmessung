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
/// import 'out/app_localizations.dart';
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
  /// **'Import a video and mark steps during playback'**
  String get modeVideoDesc;

  /// No description provided for @modeVideoInfo.
  ///
  /// In en, this message translates to:
  /// **'Import a recorded video and play it back. Mark every step as it appears in the picture to build your study from the footage, without live timing.'**
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
