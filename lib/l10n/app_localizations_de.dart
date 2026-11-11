// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'CycleScope';

  @override
  String get createStudy => 'Studie erstellen';

  @override
  String get newStudyTitle => 'Neue Studie';

  @override
  String get nameLabel => 'Name';

  @override
  String get descriptionLabel => 'Beschreibung (optional)';

  @override
  String get modeSection => 'Studienmodus';

  @override
  String get modeSimple => 'Einfach';

  @override
  String get modeSimpleDesc => 'Standard-Stoppuhr mit Runden';

  @override
  String get modeSimpleInfo =>
      'Eine klassische Stoppuhr. Jeder Rundendruck schließt die aktuelle Runde ab und startet die nächste. Keine Schritte nötig.';

  @override
  String get modeTimeStudy => 'Zeitstudie';

  @override
  String get modeTimeStudyDesc => 'Feste Abfolge definierter Schritte';

  @override
  String get modeTimeStudyInfo =>
      'Du definierst eine feste Abfolge von Schritten. Schritt 1 ist sofort beim Start aktiv. Jeder Druck springt zum nächsten Schritt; nach dem letzten Schritt beginnt ein neuer Zyklus mit Schritt 1. Ideal für sich wiederholende, geordnete Abläufe.';

  @override
  String get modeStepTimer => 'Schritt-Timer';

  @override
  String get modeStepTimerDesc =>
      'Schritte in beliebiger Reihenfolge antippen, Zeit pro Schritt';

  @override
  String get modeStepTimerInfo =>
      'Tippe einen beliebigen Schritt an, um seine Zeit zu messen. Die Zeit läuft immer für den zuletzt angetippten Schritt. Praktisch, wenn die Reihenfolge variiert.';

  @override
  String get modeVideo => 'Video-Studie';

  @override
  String get modeVideoDesc =>
      'Video importieren und Schritte bei der Wiedergabe markieren';

  @override
  String get modeVideoInfo =>
      'Importiere ein aufgenommenes Video und spiele es ab. Markiere jeden Schritt, sobald er im Bild erscheint, um die Studie direkt aus dem Material zu erstellen – ohne Live-Messung.';

  @override
  String get modeBadgeSimple => 'EINFACH';

  @override
  String get modeBadgeTimeStudy => 'ZEITSTUDIE';

  @override
  String get modeBadgeStepTimer => 'SCHRITT-TIMER';

  @override
  String get modeBadgeVideo => 'VIDEO';

  @override
  String get howItWorks => 'So funktioniert es';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get stepsLabel => 'Schritte (einer pro Zeile)';

  @override
  String stepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return '$_temp0';
  }

  @override
  String get nameRequired => 'Bitte einen Namen eingeben';

  @override
  String get stepsRequired => 'Bitte mindestens einen Schritt eingeben';

  @override
  String defaultStudyName(String number) {
    return 'Zeitstudie #$number';
  }

  @override
  String get emptyStudies =>
      'Noch keine Studien. Erstelle deine erste Zeitstudie.';

  @override
  String get createdLabel => 'Erstellt';

  @override
  String get activeLabel => 'Aktiv';

  @override
  String get cyclesLabel => 'ZYKLEN';

  @override
  String get lapsLabel => 'RUNDEN';

  @override
  String get measurementsLabel => 'ZEITEN';

  @override
  String get create => 'Erstellen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteStudy => 'Studie löschen';

  @override
  String deleteStudyConfirm(String name) {
    return '„$name“ inklusive aller Messungen löschen?';
  }

  @override
  String get totalLabel => 'GESAMT';

  @override
  String get stepLabel => 'SCHRITT';

  @override
  String get lapLabel => 'RUNDE';

  @override
  String lapNumber(int number) {
    return 'Runde $number';
  }

  @override
  String cycleNumber(int number) {
    return 'Zyklus $number';
  }

  @override
  String stepOf(int index, int count) {
    return 'Schritt $index von $count';
  }

  @override
  String nextStep(String name) {
    return 'Nächster: $name';
  }

  @override
  String get ready => 'Bereit';

  @override
  String get paused => 'PAUSIERT';

  @override
  String get recording => 'AUFNAHME';

  @override
  String get specialTimeRunning => 'SONDERZEIT';

  @override
  String get specialTime => 'Sonderzeit';

  @override
  String get noTimesYet =>
      'Noch keine Zeiten. Start drücken – Schritt 1 beginnt sofort.';

  @override
  String get start => 'START';

  @override
  String get stop => 'STOPP';

  @override
  String get resume => 'WEITER';

  @override
  String get next => 'NÄCHSTER';

  @override
  String get lap => 'RUNDE';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetConfirm =>
      'Aufnahme beenden und den unvollendeten Schritt verwerfen?';

  @override
  String get specialShort => 'HALTEN\nSONDERZEIT';

  @override
  String get specialTimeNote => 'Notiz zur Sonderzeit';

  @override
  String get specialTimeNoteHint => 'Was ist passiert? (optional)';

  @override
  String get save => 'Speichern';

  @override
  String get rebootInterrupted =>
      'Das Gerät wurde während der Aufnahme neu gestartet. Abgeschlossene Zeiten bleiben erhalten, der unvollendete Schritt wurde verworfen.';

  @override
  String get recordingInProgress => 'Aufnahme läuft';

  @override
  String recordingInProgressText(String name) {
    return '„$name“ wird noch aufgenommen. Fortsetzen?';
  }

  @override
  String get open => 'Öffnen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get recBadge => 'REC';

  @override
  String get tabLive => 'Live';

  @override
  String get tabCycles => 'Zyklen';

  @override
  String get tabLaps => 'Runden';

  @override
  String get incomplete => 'unvollständig';

  @override
  String get deleteCycle => 'Zyklus löschen';

  @override
  String get undo => 'Rückgängig';

  @override
  String deletedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeiten gelöscht',
      one: '1 Zeit gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get editStudy => 'Studie bearbeiten';

  @override
  String get renameStep => 'Schritt umbenennen';

  @override
  String get deleteStep => 'Schritt löschen';

  @override
  String deleteStepConfirm(String name) {
    return 'Schritt „$name“ löschen?';
  }

  @override
  String deleteStepWithTimes(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erfasster Zeiten',
      one: '1 erfasster Zeit',
    );
    return 'Schritt „$name“ inklusive $_temp0 löschen?';
  }

  @override
  String get stepsSection => 'Schritte';

  @override
  String get stepsEditHint =>
      'Tippen zum Umbenennen, ziehen zum Umsortieren. Erfasste Zeiten bleiben beim Schritt.';

  @override
  String get newStepHint => 'Neuer Schritt';

  @override
  String get addStep => 'Schritt hinzufügen';

  @override
  String get tabAnalysis => 'Auswertung';

  @override
  String get realCycleTime => 'Reale Taktzeit';

  @override
  String get realLapTime => 'Reale Rundenzeit';

  @override
  String get methodMean => 'Mittelwert';

  @override
  String get methodMedian => 'Median';

  @override
  String get methodIqr => 'IQR';

  @override
  String get methodHint =>
      'Mittelwert: alle Zyklen · Median: robust · IQR: Mittelwert ohne Ausreißer (1,5 × IQR)';

  @override
  String completeCycles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vollständige Zyklen',
      one: '1 vollständiger Zyklus',
    );
    return '$_temp0';
  }

  @override
  String incompleteCycles(int count) {
    return '$count unvollständig';
  }

  @override
  String outliersRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausreißer entfernt',
      one: '1 Ausreißer entfernt',
    );
    return '$_temp0';
  }

  @override
  String get mean => 'Mittelwert';

  @override
  String get median => 'Median';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Max';

  @override
  String get stdDev => 'Std.-abw.';

  @override
  String get cv => 'VarK';

  @override
  String get meanShort => 'Ø';

  @override
  String get medianShort => 'Md';

  @override
  String get specialTimesTotal => 'Sonderzeiten';

  @override
  String get specialTimesExcluded =>
      'Nicht in Schritt- oder Taktzeiten enthalten';

  @override
  String get noTimesShort => 'Keine Zeiten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get design => 'Design';

  @override
  String get language => 'Sprache';

  @override
  String get followSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get general => 'Allgemein';

  @override
  String get defaultUnit => 'Standard-Zeiteinheit';

  @override
  String get unitHm => 'HM (Hundertstelminute)';

  @override
  String get unitSeconds => 'Sekunden';

  @override
  String get unitStopwatch => 'mm:ss.SSS';

  @override
  String get unitTmu => 'TMU (MTM)';

  @override
  String get defaultMethod => 'Methode reale Taktzeit';

  @override
  String get vibration => 'Vibration';

  @override
  String get hardwareKeys => 'Hardware-Tasten';

  @override
  String get hardwareKeysHint =>
      'Lautstärke hoch: nächster Schritt (halten: Sonderzeit) · Lautstärke runter: Start/Stopp';

  @override
  String get holdThreshold => 'Haltedauer für Sonderzeit';

  @override
  String get keepScreenOn => 'Bildschirm aktiv halten';

  @override
  String get keepScreenOnHint =>
      'Bildschirmsperre während der Aufnahme verhindern';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsHint =>
      'Laufenden Schritt anzeigen, wenn die App im Hintergrund ist';

  @override
  String get about => 'Über';

  @override
  String get version => 'Version';
}
