import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/domain/statistics.dart';
import '../../backup/presentation/backup_tiles.dart';
import '../../analysis/presentation/analysis_view.dart' show methodLabel;
import '../../core/time_format.dart';
import '../../demo/presentation/demo_data_tile.dart';
import '../../l10n/app_localizations.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

/// App version shown in the settings.
const appVersion = '1.6.1';

/// Global settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _unitLabel(AppLocalizations l, TimeUnit u) => switch (u) {
    TimeUnit.hm => l.unitHm,
    TimeUnit.seconds => l.unitSeconds,
    TimeUnit.stopwatch => l.unitStopwatch,
    TimeUnit.tmu => l.unitTmu,
  };

  String _themeLabel(AppLocalizations l, ThemeChoice t) => switch (t) {
    ThemeChoice.system => l.followSystem,
    ThemeChoice.light => l.themeLight,
    ThemeChoice.dark => l.themeDark,
  };

  /// Minutes as hours ("8 h", "7.5 h").
  static String _hours(int minutes) => minutes % 60 == 0
      ? '${minutes ~/ 60} h'
      : '${(minutes / 60).toStringAsFixed(1)} h';

  String _staleLabel(AppLocalizations l, int days) =>
      days == 0 ? l.never : l.staleDaysValue(days);

  String _languageLabel(AppLocalizations l, LanguageChoice c) => switch (c) {
    LanguageChoice.system => l.followSystem,
    LanguageChoice.en => 'English',
    LanguageChoice.de => 'Deutsch',
  };

  Future<T?> _choose<T>(
    BuildContext context,
    String title,
    List<T> values,
    T current,
    String Function(T) label,
  ) => showDialog<T>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(
            children: [
              for (final v in values)
                RadioListTile<T>(value: v, title: Text(label(v))),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          header(l.appearance),
          ListTile(
            key: const Key('themeTile'),
            leading: const Icon(Icons.palette_outlined),
            title: Text(l.design),
            subtitle: Text(_themeLabel(l, s.theme)),
            onTap: () async {
              final v = await _choose(
                context,
                l.design,
                ThemeChoice.values,
                s.theme,
                (t) => _themeLabel(l, t),
              );
              if (v != null) await ctrl.update((x) => x.copyWith(theme: v));
            },
          ),
          ListTile(
            key: const Key('languageTile'),
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Text(_languageLabel(l, s.language)),
            onTap: () async {
              final v = await _choose(
                context,
                l.language,
                LanguageChoice.values,
                s.language,
                (c) => _languageLabel(l, c),
              );
              if (v != null) {
                await ctrl.update((x) => x.copyWith(language: v));
              }
            },
          ),
          header(l.general),
          ListTile(
            key: const Key('unitTile'),
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.defaultUnit),
            subtitle: Text(_unitLabel(l, s.defaultUnit)),
            onTap: () async {
              final v = await _choose(
                context,
                l.defaultUnit,
                TimeUnit.values,
                s.defaultUnit,
                (u) => _unitLabel(l, u),
              );
              if (v != null) {
                await ctrl.update((x) => x.copyWith(defaultUnit: v));
              }
            },
          ),
          ListTile(
            key: const Key('methodTile'),
            leading: const Icon(Icons.functions),
            title: Text(l.defaultMethod),
            subtitle: Text(methodLabel(l, s.defaultMethod)),
            onTap: () async {
              final v = await _choose(
                context,
                l.defaultMethod,
                CycleTimeMethod.values,
                s.defaultMethod,
                (m) => methodLabel(l, m),
              );
              if (v != null) {
                await ctrl.update((x) => x.copyWith(defaultMethod: v));
              }
            },
          ),
          SwitchListTile(
            key: const Key('vibrationSwitch'),
            secondary: const Icon(Icons.vibration),
            title: Text(l.vibration),
            value: s.vibration,
            onChanged: (v) => ctrl.update((x) => x.copyWith(vibration: v)),
          ),
          SwitchListTile(
            key: const Key('hardwareKeysSwitch'),
            secondary: const Icon(Icons.volume_up),
            title: Text(l.hardwareKeys),
            subtitle: Text(l.hardwareKeysHint),
            value: s.hardwareKeys,
            onChanged: (v) => ctrl.update((x) => x.copyWith(hardwareKeys: v)),
          ),
          ListTile(
            leading: const Icon(Icons.pan_tool_alt),
            title: Text(l.holdThreshold),
            subtitle: Slider(
              key: const Key('holdSlider'),
              min: AppSettings.minHoldMs.toDouble(),
              max: AppSettings.maxHoldMs.toDouble(),
              divisions: (AppSettings.maxHoldMs - AppSettings.minHoldMs) ~/ 50,
              value: s.holdThresholdMs.toDouble(),
              label: '${s.holdThresholdMs} ms',
              onChanged: (v) =>
                  ctrl.update((x) => x.copyWith(holdThresholdMs: v.round())),
            ),
            trailing: Text('${s.holdThresholdMs} ms'),
          ),
          SwitchListTile(
            key: const Key('keepScreenOnSwitch'),
            secondary: const Icon(Icons.smartphone),
            title: Text(l.keepScreenOn),
            subtitle: Text(l.keepScreenOnHint),
            value: s.keepScreenOn,
            onChanged: (v) => ctrl.update((x) => x.copyWith(keepScreenOn: v)),
          ),
          SwitchListTile(
            key: const Key('notificationsSwitch'),
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l.notifications),
            subtitle: Text(l.notificationsHint),
            value: s.notifications,
            onChanged: (v) => ctrl.update((x) => x.copyWith(notifications: v)),
          ),
          ListTile(
            key: const Key('staleDaysTile'),
            leading: const Icon(Icons.history),
            title: Text(l.staleDaysSetting),
            subtitle: Text(_staleLabel(l, s.staleDays)),
            onTap: () async {
              final v = await _choose<int>(
                context,
                l.staleDaysSetting,
                AppSettings.staleDayChoices,
                s.staleDays,
                (d) => _staleLabel(l, d),
              );
              if (v != null) ctrl.update((x) => x.copyWith(staleDays: v));
            },
          ),
          ListTile(
            key: const Key('shiftLengthTile'),
            leading: const Icon(Icons.schedule),
            title: Text(l.shiftLength),
            subtitle: Text(_hours(s.shiftMinutes)),
            onTap: () async {
              final v = await _choose<int>(
                context,
                l.shiftLength,
                AppSettings.shiftChoices,
                s.shiftMinutes,
                _hours,
              );
              if (v != null) ctrl.update((x) => x.copyWith(shiftMinutes: v));
            },
          ),
          ListTile(
            key: const Key('failureDurationTile'),
            leading: const Icon(Icons.build_circle_outlined),
            title: Text(l.failureDuration),
            subtitle: Text('${s.failureMinutes} min'),
            onTap: () async {
              final v = await _choose<int>(
                context,
                l.failureDuration,
                AppSettings.failureChoices,
                s.failureMinutes,
                (m) => '$m min',
              );
              if (v != null) ctrl.update((x) => x.copyWith(failureMinutes: v));
            },
          ),
          header(l.data),
          const BackupTiles(),
          const DemoDataTile(),
          header(l.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.appTitle),
            subtitle: Text('${l.version} $appVersion'),
          ),
        ],
      ),
    );
  }
}
