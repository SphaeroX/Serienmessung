import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/presentation/analysis_view.dart';
import '../../core/clock.dart';
import '../../core/providers.dart';
import '../../core/time_format.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../recording/domain/key_interpreter.dart';
import '../../recording/domain/recording_engine.dart';
import '../../recording/platform/hardware_keys.dart';
import '../../recording/presentation/cycles_view.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../recording/presentation/recording_screen.dart' show StepOverlay;
import '../../settings/presentation/settings_controller.dart';
import '../../study/presentation/edit_study_screen.dart';
import '../domain/boundary.dart';
import '../domain/position_interpolator.dart';
import '../domain/video_clock.dart';
import '../platform/video_picker.dart';
import '../platform/video_playback.dart';
import 'video_timeline.dart';

/// Creates a player per screen; overridden in tests.
final videoPlaybackFactoryProvider = Provider<VideoPlayback Function()>(
  (ref) => PluginVideoPlayback.new,
);

final videoPickerProvider = Provider<VideoPicker>((ref) => FileVideoPicker());

/// Assumed frame duration for frame stepping (30 fps).
const frameMicros = 33333;

/// Playback speeds offered in the speed menu.
const playbackSpeeds = [0.25, 0.5, 1.0, 1.5, 2.0];

/// Video study: play an imported video and mark step changes.
class VideoStudyScreen extends ConsumerStatefulWidget {
  const VideoStudyScreen({super.key, required this.studyId});

  final int studyId;

  @override
  ConsumerState<VideoStudyScreen> createState() => _VideoStudyScreenState();
}

class _VideoStudyScreenState extends ConsumerState<VideoStudyScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayback playback;
  late final RecordingController controller;
  late final Ticker _ticker;
  final _now = ValueNotifier<int>(0);
  late final HardwareKeys _keys;
  late final KeyInterpreter _interpreter;
  StreamSubscription<KeyEventData>? _keySub;
  bool _keysEnabled = true;
  bool _videoMissing = false;
  late final Clock _mono;
  final _interpolator = PositionInterpolator();

  /// Smooth video position used as the time base and for the timeline.
  int get position => _interpolator.estimate(_mono.nowMicros());

  void _report() => _interpolator.report(
    position: playback.positionMicros,
    now: _mono.nowMicros(),
    playing: playback.playing,
    speed: playback.speed,
    duration: playback.durationMicros,
  );

  /// Seeks and moves the timeline there immediately.
  Future<void> _seek(int micros) async {
    final target = micros.clamp(0, playback.durationMicros);
    _interpolator.snap(target, _mono.nowMicros());
    _now.value = target;
    await playback.seekTo(target);
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _mono = ref.read(clockProvider);
    playback = ref.read(videoPlaybackFactoryProvider)()
      ..addListener(_report)
      ..addListener(_onChanged);
    controller =
        RecordingController(
            studyId: widget.studyId,
            studies: ref.read(studyRepositoryProvider),
            measurementRepo: ref.read(measurementRepositoryProvider),
            runStates: ref.read(runStateRepositoryProvider),
            clock: VideoClock(() => position),
            feedback: ref.read(deviceFeedbackProvider),
            wallClock: ref.read(wallClockProvider),
            detectReboot: false,
          )
          ..defaultMethod = settings.defaultMethod
          ..analysisUnit = settings.defaultUnit
          ..displayUnit = settings.defaultUnit
          ..addListener(_onChanged);
    _ticker = createTicker((_) => _now.value = position)..start();

    final mono = _mono;
    int toVideo(int monoAt) => videoPositionAt(
      keyAtMonotonic: monoAt,
      nowMonotonic: mono.nowMicros(),
      videoNow: position,
      playing: playback.playing,
      speed: playback.speed,
    );
    _keys = ref.read(hardwareKeysProvider);
    _interpreter = KeyInterpreter(
      holdThreshold: Duration(milliseconds: settings.holdThresholdMs),
      onNext: (at) => _mark(at: toVideo(at)),
      onStartStop: (_) => _togglePlay(),
      onSpecialStart: (at) => controller.beginSpecial(at: toVideo(at)),
      onSpecialEnd: (at) => controller.endSpecial(at: toVideo(at)),
    );
    _keysEnabled = settings.hardwareKeys;
    if (_keysEnabled) {
      _keySub = _keys.events.listen(_interpreter.handle);
      _keys.setCapture(true);
    }
    controller.feedback.setKeepScreenOn(true);
    _load();
  }

  Future<void> _load() async {
    await controller.load();
    final path = controller.study?.videoPath;
    if (path != null) await _open(path);
  }

  Future<void> _open(String path) async {
    try {
      await playback.open(path);
    } on Object {
      // File moved/deleted or not playable.
      if (mounted) setState(() => _videoMissing = true);
      return;
    }
    // Continue where the last marker was set.
    _report();
    if (controller.status != EngineStatus.idle) {
      await _seek(controller.markerPosition);
    }
    if (mounted) setState(() => _videoMissing = false);
  }

  Future<void> _chooseVideo() async {
    final path = await ref
        .read(videoPickerProvider)
        .pickAndCopy(studyId: widget.studyId);
    if (path == null) return;
    await ref.read(studyRepositoryProvider).setVideoPath(widget.studyId, path);
    await controller.load();
    await _open(path);
  }

  void _onChanged() {
    _now.value = position;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_keysEnabled) _keys.setCapture(false);
    _keySub?.cancel();
    _interpreter.dispose();
    _ticker.dispose();
    controller.feedback.setKeepScreenOn(false);
    controller.removeListener(_onChanged);
    controller.dispose();
    playback.removeListener(_onChanged);
    playback.removeListener(_report);
    playback.dispose();
    _now.dispose();
    super.dispose();
  }

  Future<void> _mark({int? at}) async {
    final ok = await controller.mark(at: at ?? position);
    if (!ok && mounted && controller.status == EngineStatus.running) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.markerBeforeLast)));
    }
  }

  Future<void> _togglePlay() =>
      playback.playing ? playback.pause() : playback.play();

  Future<void> _step(int frames) async {
    if (playback.playing) await playback.pause();
    await _seek(playback.positionMicros + frames * frameMicros);
  }

  Future<void> _moveMarker(Boundary b, int to) async {
    final ok = await controller.moveMarker(b, to);
    if (!ok && mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.markerCannotMove)));
    }
  }

  Future<void> _editStudy() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditStudyScreen(studyId: widget.studyId),
      ),
    );
    await controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final hasVideo = playback.initialized;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.study?.name ?? ''),
        actions: [
          ExportButton(controller: controller),
          IconButton(
            key: const Key('chooseVideoAction'),
            tooltip: l.chooseVideo,
            icon: const Icon(Icons.video_library_outlined),
            onPressed: _chooseVideo,
          ),
          IconButton(
            key: const Key('editStudyButton'),
            tooltip: l.editStudy,
            icon: const Icon(Icons.edit_note),
            onPressed: c.loaded && c.status == EngineStatus.idle
                ? _editStudy
                : null,
          ),
        ],
      ),
      body: !c.loaded
          ? const Center(child: CircularProgressIndicator())
          : !hasVideo
          ? _NoVideo(missing: _videoMissing, onChoose: _chooseVideo)
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  _VideoArea(playback: playback),
                  _Transport(
                    playback: playback,
                    now: _now,
                    onToggle: _togglePlay,
                    onStep: _step,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: VideoTimeline(
                      position: _now,
                      durationMicros: playback.durationMicros,
                      measurements: c.measurements,
                      steps: c.steps,
                      onSeek: _seek,
                      onMoveBoundary: _moveMarker,
                      onScrubStart: () {
                        if (playback.playing) playback.pause();
                      },
                    ),
                  ),
                  StepOverlay(controller: c, now: _now),
                  TabBar(
                    tabs: [
                      Tab(text: l.tabCycles),
                      Tab(key: const Key('analysisTab'), text: l.tabAnalysis),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        CyclesView(controller: c),
                        AnalysisView(controller: c),
                      ],
                    ),
                  ),
                  _MarkBar(
                    controller: c,
                    onMark: () => _mark(),
                    onSpecialDown: () => c.beginSpecial(at: position),
                    onSpecialUp: () => c.endSpecial(at: position),
                  ),
                ],
              ),
            ),
    );
  }
}

class _NoVideo extends StatelessWidget {
  const _NoVideo({required this.missing, required this.onChoose});

  final bool missing;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              missing ? l.videoMissing : l.noVideoYet,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('chooseVideoButton'),
              onPressed: onChoose,
              icon: const Icon(Icons.video_library),
              label: Text(l.chooseVideo),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoArea extends StatelessWidget {
  const _VideoArea({required this.playback});

  final VideoPlayback playback;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.32;
    return Container(
      color: Colors.black,
      constraints: BoxConstraints(maxHeight: maxHeight),
      width: double.infinity,
      child: Center(
        child: AspectRatio(
          aspectRatio: playback.aspectRatio,
          child: playback.buildView(),
        ),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playback,
    required this.now,
    required this.onToggle,
    required this.onStep,
  });

  final VideoPlayback playback;
  final ValueNotifier<int> now;
  final VoidCallback onToggle;
  final void Function(int frames) onStep;

  String _speed(double s) => '${s.toString().replaceAll(RegExp(r'\.0$'), '')}×';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Shrinks on narrow phones instead of overflowing.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<int>(
                valueListenable: now,
                builder: (context, t, _) => Text(
                  '${formatTime(t, TimeUnit.stopwatch)} / '
                  '${formatTime(playback.durationMicros, TimeUnit.stopwatch)}',
                  key: const Key('videoPosition'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('frameBack'),
            visualDensity: VisualDensity.compact,
            tooltip: l.frameBack,
            icon: const Icon(Icons.skip_previous),
            onPressed: () => onStep(-1),
          ),
          IconButton.filled(
            key: const Key('playPause'),
            icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
            onPressed: onToggle,
          ),
          IconButton(
            key: const Key('frameForward'),
            visualDensity: VisualDensity.compact,
            tooltip: l.frameForward,
            icon: const Icon(Icons.skip_next),
            onPressed: () => onStep(1),
          ),
          PopupMenuButton<double>(
            key: const Key('speedMenu'),
            tooltip: l.playbackSpeed,
            initialValue: playback.speed,
            onSelected: playback.setSpeed,
            itemBuilder: (_) => [
              for (final s in playbackSpeeds)
                PopupMenuItem(
                  value: s,
                  key: Key('speed-$s'),
                  child: Text(_speed(s)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _speed(playback.speed),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkBar extends StatelessWidget {
  const _MarkBar({
    required this.controller,
    required this.onMark,
    required this.onSpecialDown,
    required this.onSpecialUp,
  });

  final RecordingController controller;
  final VoidCallback onMark;
  final VoidCallback onSpecialDown;
  final VoidCallback onSpecialUp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    final running = c.status == EngineStatus.running;
    final special = c.status == EngineStatus.special;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            IconButton.outlined(
              key: const Key('undoMarker'),
              tooltip: l.undoMarker,
              icon: const Icon(Icons.undo),
              onPressed: c.status == EngineStatus.idle && c.measurements.isEmpty
                  ? null
                  : c.undoLastMarker,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Listener(
                key: const Key('specialButton'),
                onPointerDown: running ? (_) => onSpecialDown() : null,
                onPointerUp: (running || special) ? (_) => onSpecialUp() : null,
                child: Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: special ? scheme.error : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    l.specialShort,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: special ? scheme.onError : scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 72,
                child: FilledButton.icon(
                  key: const Key('markButton'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: special ? null : onMark,
                  icon: const Icon(Icons.flag),
                  label: FittedBox(
                    child: Text(
                      c.status == EngineStatus.idle ? l.markStart : l.mark,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
