import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../study/domain/study.dart';
import '../domain/measurement.dart';
import '../domain/recording_engine.dart';
import 'recording_controller.dart';

/// Live recording screen with the always-visible current-step overlay.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.studyId});

  final int studyId;

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with SingleTickerProviderStateMixin {
  late final RecordingController controller;
  late final Ticker _ticker;
  final _now = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    controller = RecordingController(
      studyId: widget.studyId,
      studies: ref.read(studyRepositoryProvider),
      measurementRepo: ref.read(measurementRepositoryProvider),
      clock: ref.read(clockProvider),
      feedback: ref.read(deviceFeedbackProvider),
      wallClock: ref.read(wallClockProvider),
    );
    controller.addListener(_onChanged);
    controller.load();
    _ticker = createTicker((_) => _now.value = controller.clock.nowMicros())
      ..start();
  }

  void _onChanged() {
    _now.value = controller.clock.nowMicros();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    controller.feedback.setKeepScreenOn(false);
    controller.removeListener(_onChanged);
    controller.dispose();
    _now.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reset),
        content: Text(l.resetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.reset),
          ),
        ],
      ),
    );
    if (ok == true) await controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.study?.name ?? ''),
        actions: [
          IconButton(
            key: const Key('resetButton'),
            tooltip: l.reset,
            icon: const Icon(Icons.restart_alt),
            onPressed: c.status == EngineStatus.idle ? null : _confirmReset,
          ),
        ],
      ),
      body: !c.loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TimerTiles(controller: c, now: _now),
                StepOverlay(controller: c, now: _now),
                Expanded(child: LiveList(controller: c)),
                ControlBar(controller: c),
              ],
            ),
    );
  }
}

/// Total time and current step/lap time tiles.
class _TimerTiles extends StatelessWidget {
  const _TimerTiles({required this.controller, required this.now});

  final RecordingController controller;
  final ValueNotifier<int> now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ValueListenableBuilder<int>(
      valueListenable: now,
      builder: (context, t, _) {
        final total = c.totalElapsed(t);
        final step = c.engine.currentStepElapsed(t);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _TimeTile(label: l.totalLabel, micros: total),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeTile(
                  label: c.hasSteps ? l.stepLabel : l.lapLabel,
                  micros: step,
                  valueKey: const Key('stepTime'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.micros, this.valueKey});

  final String label;
  final int micros;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2),
          ),
          FittedBox(
            child: Text(
              formatTime(micros, TimeUnit.stopwatch),
              key: valueKey,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            formatTime(micros, TimeUnit.hm, locale: locale),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Large card that always shows which step is being timed right now.
class StepOverlay extends StatelessWidget {
  const StepOverlay({super.key, required this.controller, required this.now});

  final RecordingController controller;
  final ValueNotifier<int> now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = controller;
    final status = c.status;
    final special = status == EngineStatus.special;
    final scheme = theme.colorScheme;
    final bg = switch (status) {
      EngineStatus.special => scheme.errorContainer,
      EngineStatus.running => scheme.primaryContainer,
      _ => scheme.surfaceContainerHighest,
    };
    final fg = switch (status) {
      EngineStatus.special => scheme.onErrorContainer,
      EngineStatus.running => scheme.onPrimaryContainer,
      _ => scheme.onSurface,
    };
    final step = c.currentStep;
    final mode = c.study?.mode ?? StudyMode.timeStudy;
    final name = c.hasSteps ? (step?.name ?? '') : l.lapNumber(c.displayCycle);
    final statusText = switch (status) {
      EngineStatus.idle => l.ready,
      EngineStatus.paused => l.paused,
      EngineStatus.special => l.specialTimeRunning,
      EngineStatus.running => l.recording,
    };

    return Container(
      key: const Key('stepOverlay'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!.copyWith(color: fg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (mode != StudyMode.stepTimer && mode != StudyMode.simple)
                  Text(
                    l.cycleNumber(c.displayCycle),
                    key: const Key('cycleLabel'),
                    style: theme.textTheme.labelLarge?.copyWith(color: fg),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              key: const Key('currentStepName'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (c.hasSteps && mode != StudyMode.stepTimer) ...[
              Text(
                l.stepOf(c.currentStepIndex + 1, c.steps.length),
                key: const Key('stepPosition'),
              ),
              if (c.steps.length > 1)
                Text(
                  l.nextStep(c.nextStep?.name ?? ''),
                  key: const Key('nextStepName'),
                  style: TextStyle(color: fg.withValues(alpha: 0.75)),
                ),
            ],
            if (special)
              ValueListenableBuilder<int>(
                valueListenable: now,
                builder: (context, t, _) => Text(
                  formatTime(c.engine.specialElapsed(t), TimeUnit.stopwatch),
                  key: const Key('specialTime'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: fg,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Recorded times, newest first.
class LiveList extends StatelessWidget {
  const LiveList({super.key, required this.controller});

  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final c = controller;
    final items = c.measurements;
    if (items.isEmpty) {
      return Center(
        child: Text(l.noTimesYet, style: theme.textTheme.bodyMedium),
      );
    }
    // Running total in chronological order.
    final cumulative = <int>[];
    var sum = 0;
    for (final m in items) {
      sum += m.durationMicros;
      cumulative.add(sum);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final idx = items.length - 1 - i;
        final m = items[idx];
        final special = m.kind == MeasurementKind.special;
        final title = special
            ? (m.note.isEmpty ? l.specialTime : '${l.specialTime}: ${m.note}')
            : (c.hasSteps
                  ? (c.stepById(m.stepId)?.name ?? '?')
                  : l.lapNumber(m.cycle));
        return ListTile(
          key: const Key('liveRow'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 44,
            child: Text(
              c.study?.mode == StudyMode.stepTimer
                  ? '#${idx + 1}'
                  : '#${m.cycle}',
              style: theme.textTheme.labelMedium,
            ),
          ),
          title: Text(
            title,
            style: special ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          subtitle: Text(
            formatTime(cumulative[idx], TimeUnit.stopwatch),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTime(m.durationMicros, TimeUnit.stopwatch),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                formatTime(
                  m.durationMicros,
                  TimeUnit.hm,
                  decimals: 1,
                  locale: locale,
                ),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Large buttons for one-handed operation.
class ControlBar extends StatelessWidget {
  const ControlBar({super.key, required this.controller});

  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    final status = c.status;
    final (label, icon) = switch (status) {
      EngineStatus.idle => (l.start, Icons.play_arrow),
      EngineStatus.running || EngineStatus.special => (l.stop, Icons.pause),
      EngineStatus.paused => (l.resume, Icons.play_arrow),
    };
    final nextLabel = c.hasSteps ? l.next : l.lap;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: _BigButton(
                key: const Key('startStopButton'),
                label: label,
                icon: icon,
                background: status == EngineStatus.running
                    ? scheme.secondaryContainer
                    : scheme.primary,
                foreground: status == EngineStatus.running
                    ? scheme.onSecondaryContainer
                    : scheme.onPrimary,
                onPressed: status == EngineStatus.special
                    ? null
                    : () => c.startStop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _BigButton(
                key: const Key('nextButton'),
                label: nextLabel,
                icon: Icons.skip_next,
                background: scheme.tertiary,
                foreground: scheme.onTertiary,
                onPressed: status == EngineStatus.running
                    ? () => c.next()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
