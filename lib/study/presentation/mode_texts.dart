import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../domain/study.dart';

/// Localized texts and icons per [StudyMode].
extension StudyModeTexts on StudyMode {
  String title(AppLocalizations l) => switch (this) {
    StudyMode.simple => l.modeSimple,
    StudyMode.timeStudy => l.modeTimeStudy,
    StudyMode.stepTimer => l.modeStepTimer,
    StudyMode.video => l.modeVideo,
  };

  String description(AppLocalizations l) => switch (this) {
    StudyMode.simple => l.modeSimpleDesc,
    StudyMode.timeStudy => l.modeTimeStudyDesc,
    StudyMode.stepTimer => l.modeStepTimerDesc,
    StudyMode.video => l.modeVideoDesc,
  };

  String info(AppLocalizations l) => switch (this) {
    StudyMode.simple => l.modeSimpleInfo,
    StudyMode.timeStudy => l.modeTimeStudyInfo,
    StudyMode.stepTimer => l.modeStepTimerInfo,
    StudyMode.video => l.modeVideoInfo,
  };

  String badge(AppLocalizations l) => switch (this) {
    StudyMode.simple => l.modeBadgeSimple,
    StudyMode.timeStudy => l.modeBadgeTimeStudy,
    StudyMode.stepTimer => l.modeBadgeStepTimer,
    StudyMode.video => l.modeBadgeVideo,
  };

  IconData get icon => switch (this) {
    StudyMode.simple => Icons.timer_outlined,
    StudyMode.timeStudy => Icons.assignment_outlined,
    StudyMode.stepTimer => Icons.touch_app_outlined,
    StudyMode.video => Icons.movie_outlined,
  };
}
