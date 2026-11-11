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
