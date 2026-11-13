import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/presentation/analysis_view.dart';
import '../../core/clock.dart';
import '../../core/providers.dart';
import '../../core/time_format.dart';
import '../../export/presentation/export_menu.dart';
import '../../l10n/app_localizations.dart';
import '../../revision/presentation/revisions_screen.dart';
import '../../recording/domain/key_interpreter.dart';
import '../../recording/domain/recording_engine.dart';
import '../../recording/platform/hardware_keys.dart';
import '../../recording/presentation/cycles_view.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../recording/presentation/recording_screen.dart'
    show RecordingScreen, StepOverlay;
import '../../settings/presentation/settings_controller.dart';
import '../../study/presentation/edit_study_screen.dart';
import '../data/video_cleanup.dart';
import '../domain/boundary.dart';
import '../domain/frame_cache.dart';
import '../domain/position_interpolator.dart';
import '../domain/video_clock.dart';
import '../platform/frame_source.dart';
import '../platform/video_picker.dart';
import '../platform/video_playback.dart';
import 'step_names_dialog.dart';
import 'video_timeline.dart';

/// Creates a player per screen; overridden in tests.
final videoPlaybackFactoryProvider = Provider<VideoPlayback Function()>(
  (ref) => PluginVideoPlayback.new,
);

/// Creates a frame decoder per screen; overridden in tests.
final frameSourceFactoryProvider = Provider<FrameSource Function()>(
  (ref) => ChannelFrameSource.new,
);

final videoPickerProvider = Provider<VideoPicker>((ref) => FileVideoPicker());

/// Frame duration used when the video's frame rate is unknown (30 fps).
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
    with TickerProviderStateMixin {
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
  late final FrameSource _frameSource;
  FrameTiming _timing = const FrameTiming.fallback(durationMicros: 0);
  FrameCache<Uint8List>? _cache;

  /// Frame shown after frame stepping (decoded in advance), above the video.
  int? _frameIndex;
  Uint8List? _frame;
  Timer? _prefetchTimer;
  bool _wasPlaying = false;

  /// Marking (video), cycles and analysis; only the marking tab shows the
  /// video so the lists get the whole screen.
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(_onTab);
  int _tab = 0;

  void _onTab() {
    if (_tabs.index == _tab) return;
    if (_tabs.index != 0 && playback.playing) unawaited(playback.pause());
    setState(() => _tab = _tabs.index);
  }

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
  Future<void> _seek(int micros, {bool keepFrame = false}) async {
    if (!keepFrame) {
      _hideFrame();
      _schedulePrefetch();
    }
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
    _frameSource = ref.read(frameSourceFactoryProvider)();
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
          ..onAnalysisUnitChosen = _saveUnit
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
    await _openFrames(path);
    // Continue where the last marker was set.
    _report();
    if (controller.status != EngineStatus.idle) {
      await _seek(controller.markerPosition);
    }
    if (mounted) setState(() => _videoMissing = false);
  }

  Future<void> _openFrames(String path) async {
    _cache?.clear();
    _cache = null;
    _hideFrame();
    FrameTiming? timing;
    try {
      timing = await _frameSource.open(path);
    } on Object {
      timing = null;
    }
    _timing =
        timing ?? FrameTiming.fallback(durationMicros: playback.durationMicros);
    if (timing != null) {
      _cache = FrameCache<Uint8List>(
        frameCount: timing.frameCount,
        fetch: _frameSource.frames,
      );
      unawaited(_cache!.prefetchAround(_timing.indexAt(position)));
    }
  }

  /// Decodes the frames around the position once it rests for a moment.
  void _schedulePrefetch() {
    final cache = _cache;
    if (cache == null) return;
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && !playback.playing) {
        unawaited(cache.prefetchAround(_timing.indexAt(position)));
      }
    });
  }

  void _hideFrame() {
    if (_frameIndex == null && _frame == null) return;
    _frameIndex = null;
    _frame = null;
    if (mounted) setState(() {});
  }

  Future<void> _chooseVideo() async {
    final path = await ref
        .read(videoPickerProvider)
        .pickAndCopy(studyId: widget.studyId);
    if (path == null || !mounted) return;
    final studies = ref.read(studyRepositoryProvider);
    final files = ref.read(videoFilesProvider);
    final old = controller.study?.videoPath;
    if (controller.measurements.isNotEmpty) {
      final l = AppLocalizations.of(context);
      final delete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.replaceVideoTitle),
          content: Text(l.replaceVideoBody),
          actions: [
            TextButton(
              key: const Key('keepOldCycles'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.keepCycles),
            ),
            FilledButton(
              key: const Key('deleteOldCycles'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.deleteCycles),
            ),
          ],
        ),
      );
      if (delete == null) {
        // Cancelled: the copy made by the picker is not needed.
        await deleteUnusedVideo(studies, files, path);
        return;
      }
      if (delete) await controller.deleteAllMeasurements();
    }
    // Markers of the old video must not block positions in the new one.
    await controller.resetMarkers();
    await studies.setVideoPath(widget.studyId, path);
    await controller.load();
    await _open(path);
    // The player has let go of the old file by now.
    if (old != path) await deleteUnusedVideo(studies, files, old);
  }

  void _saveUnit(TimeUnit unit) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(defaultUnit: unit));

  void _onChanged() {
    final playing = playback.playing;
    if (playing) _hideFrame();
    if (_wasPlaying && !playing) _schedulePrefetch();
    _wasPlaying = playing;
    _now.value = position;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_keysEnabled) _keys.setCapture(false);
    _keySub?.cancel();
    _interpreter.dispose();
    _ticker.dispose();
    _tabs.dispose();
    _prefetchTimer?.cancel();
    _cache?.clear();
    unawaited(_frameSource.close());
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

  /// Steps [frames] frames; shows the decoded frame at once if available
  /// while the player seeks.
  Future<void> _step(int frames) async {
    if (playback.playing) await playback.pause();
    final from = _frameIndex ?? _timing.indexAt(position);
    final index = _timing.clampIndex(from + frames);
    final cache = _cache;
    setState(() {
      _frameIndex = index;
      _frame = cache?[index];
    });
    await _seek(_timing.timeOf(index), keepFrame: true);
    if (cache == null) return;
    await cache.prefetchAround(index);
    if (mounted && _frameIndex == index && _frame == null) {
      setState(() => _frame = cache[index]);
    }
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

  /// Ends the current cycle; the first cycle of a study that defines its
  /// steps by markers then asks for the step names.
  Future<void> _closeCycle() async {
    final definingSteps = controller.stepsOpen;
    final ok = await controller.closeCycle(at: position);
    if (!mounted) return;
    if (!ok) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.closeCycleRejected)));
      return;
    }
    if (definingSteps) await _nameSteps();
  }

  /// Lets the user name the steps created by the markers.
  Future<void> _nameSteps() async {
    if (playback.playing) await playback.pause();
    if (!mounted) return;
    final steps = controller.steps;
    final names = await showDialog<List<String>>(
      context: context,
      builder: (_) => StepNamesDialog(names: [for (final s in steps) s.name]),
    );
    if (names == null) return;
    final repo = ref.read(studyRepositoryProvider);
    for (var i = 0; i < steps.length; i++) {
      if (names[i] != steps[i].name) {
        await repo.renameStep(steps[i].id, names[i]);
      }
    }
    await controller.reloadSteps();
  }

  /// Creates a live time study with this study's steps and opens it.
  Future<void> _useAsTimeStudy() async {
    final l = AppLocalizations.of(context);
    final id = await ref
        .read(studyRepositoryProvider)
        .copyAsTimeStudy(
          widget.studyId,
          name: l.liveStudyName(controller.study?.name ?? ''),
          now: ref.read(wallClockProvider)(),
        );
    ref.invalidate(studyListProvider);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => RecordingScreen(studyId: id)),
    );
  }

  Future<void> _editStudy() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditStudyScreen(studyId: widget.studyId),
      ),
    );
    await controller.load();
  }

  /// Video, transport, timeline, current step and the marker buttons.
  Widget _markTab(RecordingController c) => Column(
    children: [
      Expanded(
        child: _VideoArea(playback: playback, frame: _frame),
      ),
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
      _MarkBar(
        controller: c,
        onMark: () => _mark(),
        onCloseCycle: _closeCycle,
        onSpecialDown: () => c.beginSpecial(at: position),
        onSpecialUp: () => c.endSpecial(at: position),
      ),
    ],
  );

  Future<void> _openRevisions() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final number = await openRevisions(
      context,
      studyId: widget.studyId,
      unit: controller.analysisUnit,
      method: controller.cycleTimeMethod,
      canStartNew: controller.status == EngineStatus.idle,
    );
    if (number == null) return;
    await controller.load();
    messenger.showSnackBar(
      SnackBar(content: Text(l.newRevisionStarted(number))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final hasVideo = playback.initialized;
    c.newStepName = l.newStepName;
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
          PopupMenuButton<void>(
            key: const Key('studyMenu'),
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                key: const Key('revisionsItem'),
                enabled: c.loaded,
                onTap: _openRevisions,
                child: Text(l.revisions),
              ),
              PopupMenuItem<void>(
                key: const Key('useAsTimeStudy'),
                enabled: c.steps.isNotEmpty && !c.stepsOpen,
                onTap: _useAsTimeStudy,
                child: Text(l.useAsTimeStudy),
              ),
            ],
          ),
        ],
      ),
      body: !c.loaded
          ? const Center(child: CircularProgressIndicator())
          : !hasVideo
          ? _NoVideo(missing: _videoMissing, onChoose: _chooseVideo)
          : Column(
              children: [
                TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(key: const Key('markTab'), text: l.tabMark),
                    Tab(key: const Key('cyclesTab'), text: l.tabCycles),
                    Tab(key: const Key('analysisTab'), text: l.tabAnalysis),
                  ],
                ),
                Expanded(
                  child: switch (_tab) {
                    0 => _markTab(c),
                    1 => CyclesView(controller: c),
                    _ => AnalysisView(controller: c),
                  },
                ),
              ],
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

/// Video view that can be zoomed (pinch) and panned while zoomed, e.g. to
/// see a small hand movement. Double tap or the reset button returns to the
/// full picture.
class _VideoArea extends StatefulWidget {
  const _VideoArea({required this.playback, this.frame});

  final VideoPlayback playback;

  /// Decoded frame shown instead of the player picture (frame stepping).
  final Uint8List? frame;

  @override
  State<_VideoArea> createState() => _VideoAreaState();
}

class _VideoAreaState extends State<_VideoArea> {
  final _zoom = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
  }

  void _onZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _reset() => _zoom.value = Matrix4.identity();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: _reset,
              child: InteractiveViewer(
                key: const Key('videoZoom'),
                transformationController: _zoom,
                minScale: 1,
                maxScale: 8,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.playback.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.playback.buildView(),
                        if (widget.frame case final frame?)
                          Image.memory(
                            frame,
                            key: const Key('cachedFrame'),
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_zoomed)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(
                key: const Key('resetZoom'),
                tooltip: l.resetZoom,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.zoom_out_map),
                onPressed: _reset,
              ),
            ),
        ],
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
    required this.onCloseCycle,
    required this.onSpecialDown,
    required this.onSpecialUp,
  });

  final RecordingController controller;
  final VoidCallback onMark;
  final VoidCallback onCloseCycle;
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
              flex: 2,
              child: Listener(
                key: const Key('specialButton'),
                onPointerDown: running ? (_) => onSpecialDown() : null,
                onPointerUp: (running || special) ? (_) => onSpecialUp() : null,
                child: Container(
                  height: _height,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: special ? scheme.error : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.specialShort,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: special
                            ? scheme.onError
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _MarkButton(
                buttonKey: const Key('markButton'),
                icon: Icons.flag,
                label: c.status == EngineStatus.idle ? l.markStart : l.mark,
                onPressed: special ? null : onMark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _MarkButton(
                buttonKey: const Key('closeCycleButton'),
                icon: Icons.replay,
                label: l.cycleMark,
                tooltip: l.closeCycle,
                tonal: true,
                onPressed: running ? onCloseCycle : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _height = 72.0;
const _radius = 24.0;

/// Tall button with an icon above a short label.
class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.tonal = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      minimumSize: const Size(0, _height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
      ),
    );
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
    final button = tonal
        ? FilledButton.tonal(
            key: buttonKey,
            style: style,
            onPressed: onPressed,
            child: child,
          )
        : FilledButton(
            key: buttonKey,
            style: style,
            onPressed: onPressed,
            child: child,
          );
    return SizedBox(
      height: _height,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button),
    );
  }
}
