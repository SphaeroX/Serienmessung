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
      'Video importieren und die Schritte beim Markieren festlegen';

  @override
  String get modeVideoInfo =>
      'Importiere ein aufgenommenes Video und spiele es ab. Schritte musst du vorher nicht anlegen: Im ersten Zyklus beginnt jeder Marker einen neuen Schritt. Am Ende des Zyklus „Zyklus fertig“ tippen und die Schritte benennen. Weitere Marker folgen dann Zyklus für Zyklus diesen Schritten. Anschließend kannst du die Schritte für eine Live-Zeitstudie übernehmen.';

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
  String get replaceVideoTitle => 'Video ersetzen?';

  @override
  String get replaceVideoBody =>
      'Die erfassten Zyklen gehören zum bisherigen Video. Löschen oder behalten?';

  @override
  String get keepCycles => 'Behalten';

  @override
  String get deleteCycles => 'Zyklen löschen';

  @override
  String get tabMark => 'Markieren';

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

  @override
  String get holdToDictate => 'Zum Diktieren halten';

  @override
  String get listening => 'Höre zu…';

  @override
  String get dictationUnavailable =>
      'Spracherkennung ist nicht verfügbar oder der Mikrofonzugriff wurde verweigert.';

  @override
  String get chooseVideo => 'Video auswählen';

  @override
  String get noVideoYet =>
      'Wähle ein aufgenommenes Video, um die Schritte bei der Wiedergabe zu markieren.';

  @override
  String get videoMissing =>
      'Das Video dieser Studie wurde nicht gefunden. Bitte erneut auswählen.';

  @override
  String get frameBack => 'Vorheriges Bild';

  @override
  String get frameForward => 'Nächstes Bild';

  @override
  String get playbackSpeed => 'Wiedergabetempo';

  @override
  String get undoMarker => 'Letzten Marker entfernen';

  @override
  String get markStart => 'START';

  @override
  String get mark => 'SCHRITT';

  @override
  String get markerBeforeLast =>
      'Diese Position liegt vor dem letzten Marker. Video erst weiter vorspulen.';

  @override
  String get markerCannotMove =>
      'Ein Marker kann nicht über seine Nachbarn hinaus verschoben werden.';

  @override
  String get tabTimes => 'Zeiten';

  @override
  String get export => 'Exportieren';

  @override
  String get exportCsv => 'CSV';

  @override
  String get exportCsvHint => 'Alle Zeiten als Tabelle, öffnet in Excel';

  @override
  String get exportXlsx => 'Excel (.xlsx)';

  @override
  String get exportXlsxHint => 'Zeiten, Zyklen-Matrix und Auswertung';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get exportStudy => 'Studie';

  @override
  String get exportDescription => 'Beschreibung';

  @override
  String get studyNotes => 'Notizen';

  @override
  String get studyNotesHint => 'z. B. Arbeitsplatz, Schicht, Besonderheiten';

  @override
  String get exportDate => 'Exportiert';

  @override
  String get exportUnit => 'Einheit';

  @override
  String get exportCycle => 'Zyklus';

  @override
  String get exportLap => 'Runde';

  @override
  String get exportStepNo => 'Schritt-Nr.';

  @override
  String get exportStep => 'Schritt';

  @override
  String get exportStart => 'Beginn';

  @override
  String get exportEnd => 'Ende';

  @override
  String get exportDuration => 'Dauer';

  @override
  String get exportType => 'Typ';

  @override
  String get exportNote => 'Notiz';

  @override
  String get exportStepTime => 'Schrittzeit';

  @override
  String get exportSheetTimes => 'Zeiten';

  @override
  String get exportTotal => 'Summe';

  @override
  String get exportComplete => 'Vollständig';

  @override
  String get exportYes => 'ja';

  @override
  String get exportNo => 'nein';

  @override
  String get exportRealTime => 'Reale Zeit';

  @override
  String get exportShare => 'Anteil';

  @override
  String get exportOutliers => 'Entfernte Ausreißer';

  @override
  String get exportPdf => 'PDF-Bericht';

  @override
  String get exportPdfHint =>
      'Druckfertige Auswertung mit Kennzahlen und Zyklen';

  @override
  String get reportTitle => 'Zeitstudien-Bericht';

  @override
  String get reportKeyFigures => 'Kennzahlen';

  @override
  String reportPageOf(int page, int pages) {
    return 'Seite $page von $pages';
  }

  @override
  String get reportNoData => 'Keine Zeiten erfasst.';

  @override
  String get data => 'Daten';

  @override
  String get createBackup => 'Backup erstellen';

  @override
  String get createBackupHint =>
      'Alle Studien in eine Datei sichern (ohne Videos)';

  @override
  String get restoreBackup => 'Backup wiederherstellen';

  @override
  String get restoreBackupHint => 'Studien aus einer Backup-Datei importieren';

  @override
  String get restoreChoice =>
      'Studien aus der Datei zu den vorhandenen hinzufügen oder alles ersetzen?';

  @override
  String get restoreMerge => 'Hinzufügen';

  @override
  String get restoreReplace => 'Alles ersetzen';

  @override
  String get restoreReplaceWarning =>
      'Alle Studien auf diesem Gerät werden gelöscht und durch das Backup ersetzt. Das kann nicht rückgängig gemacht werden.';

  @override
  String restoreResult(int imported, int skipped) {
    return '$imported importiert, $skipped bereits vorhanden.';
  }

  @override
  String get restoreVideoHint =>
      'Video-Studien: Video auf diesem Gerät erneut auswählen.';

  @override
  String get restoreInvalid =>
      'Das ist keine gültige Backup-Datei. Es wurde nichts geändert.';

  @override
  String get restoreTooNew =>
      'Dieses Backup stammt aus einer neueren App-Version. Bitte die App aktualisieren.';

  @override
  String newStepName(int number) {
    return 'Schritt $number';
  }

  @override
  String get resetZoom => 'Ganzes Bild zeigen';

  @override
  String get cycleMark => 'ZYKLUS';

  @override
  String get closeCycle => 'Zyklus fertig';

  @override
  String get definingSteps =>
      'Jeder SCHRITT-Marker legt einen Schritt an. Am Ende des Zyklus auf ZYKLUS tippen.';

  @override
  String get firstMarkerHint =>
      'Ersten Marker dort setzen, wo der erste Schritt beginnt';

  @override
  String get nameStepsTitle => 'Schritte benennen';

  @override
  String get useAsTimeStudy => 'Schritte als Live-Zeitstudie übernehmen';

  @override
  String liveStudyName(String name) {
    return '$name (live)';
  }

  @override
  String get closeCycleRejected =>
      'Der Zyklus kann nur nach dem letzten Marker im letzten Schritt abgeschlossen werden.';

  @override
  String get groups => 'Gruppen';

  @override
  String get emptyGroups => 'Noch keine Gruppen';

  @override
  String get emptyGroupsHint =>
      'Gruppen fassen Studien zusammen, zum Beispiel die Maschinen einer Fertigungslinie, in fester Reihenfolge.';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get editGroup => 'Gruppe bearbeiten';

  @override
  String get deleteGroup => 'Gruppe löschen';

  @override
  String deleteGroupConfirm(String name) {
    return 'Gruppe \"$name\" löschen? Ihre Studien bleiben ohne Gruppe erhalten.';
  }

  @override
  String groupStudyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Studien',
      one: '1 Studie',
    );
    return '$_temp0';
  }

  @override
  String get emptyGroupStudies => 'Noch keine Studien in dieser Gruppe';

  @override
  String get addStudies => 'Studien hinzufügen';

  @override
  String get addNewStudy => 'Neue Studie anlegen';

  @override
  String get addExistingStudies => 'Vorhandene Studien hinzufügen';

  @override
  String get addExistingHint =>
      'Studien aus anderen Gruppen werden hierher verschoben.';

  @override
  String get noStudiesToAdd => 'Alle Studien sind bereits in dieser Gruppe.';

  @override
  String get add => 'Hinzufügen';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get moveToGroup => 'In Gruppe verschieben …';

  @override
  String get copyToGroup => 'In Gruppe kopieren …';

  @override
  String get removeFromGroup => 'Aus Gruppe entfernen';

  @override
  String get chooseGroup => 'Gruppe wählen';

  @override
  String get noGroup => 'Keine Gruppe';

  @override
  String copyName(String name) {
    return '$name (Kopie)';
  }

  @override
  String studyCopied(String name) {
    return 'Kopie angelegt: $name';
  }

  @override
  String get reorderHint => 'Am Griff ziehen, um die Reihenfolge zu ändern.';

  @override
  String get revisions => 'Revisionen';

  @override
  String revisionCurrent(int number) {
    return 'Revision $number (aktuell)';
  }

  @override
  String revisionTitle(int number) {
    return 'Revision $number';
  }

  @override
  String lastMeasured(String date) {
    return 'Letzte Messung: $date';
  }

  @override
  String measuredRange(String from, String to) {
    return 'Gemessen $from – $to';
  }

  @override
  String get newRevision => 'Neue Messung beginnen';

  @override
  String get newRevisionHint =>
      'Die Studie erneut messen (z. B. ein Jahr später). Die aktuellen Zeiten werden als Revision archiviert und bleiben zum Vergleich erhalten.';

  @override
  String newRevisionConfirm(int number) {
    return 'Die aktuellen Zeiten bleiben als Revision $number zum Vergleich erhalten. Die Studie beginnt danach leer mit denselben Schritten.';
  }

  @override
  String newRevisionStarted(int number) {
    return 'Revision $number begonnen';
  }

  @override
  String get stopRecordingFirst => 'Zuerst die Aufnahme beenden.';

  @override
  String get noRevisions => 'Noch keine früheren Revisionen.';

  @override
  String get revisionThen => 'Damals';

  @override
  String get revisionNow => 'Jetzt';

  @override
  String get revisionDelta => 'Δ';

  @override
  String get deleteRevision => 'Revision löschen';

  @override
  String deleteRevisionConfirm(int number) {
    return 'Revision $number mit allen Zeiten löschen?';
  }

  @override
  String removedStep(String name) {
    return '$name (entfernt)';
  }

  @override
  String get revisionNoTimes => 'Noch keine Zeiten erfasst.';

  @override
  String staleTitle(int days) {
    return 'Messung ist $days Tage alt';
  }

  @override
  String staleText(String name, String date, int number) {
    return 'Die letzte Zeit von \"$name\" wurde am $date erfasst. Neue Messung beginnen? Die bisherigen Zeiten bleiben als Revision $number zum Vergleich erhalten.';
  }

  @override
  String get staleNewRevision => 'Neue Messung';

  @override
  String get staleContinue => 'Fortsetzen';

  @override
  String get staleDaysSetting => 'Neue Messung vorschlagen';

  @override
  String staleDaysValue(int days) {
    return 'Nach $days Tagen';
  }

  @override
  String get never => 'Nie';
}
