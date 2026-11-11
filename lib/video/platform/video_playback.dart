import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Video playback behind an interface so the screen and the timing logic can
/// be tested without a real player. Notifies listeners on every change.
abstract class VideoPlayback extends ChangeNotifier {
  Future<void> open(String path);
  bool get initialized;

  /// Position as reported by the player (may lag behind real playback).
  int get positionMicros;
  int get durationMicros;
  bool get playing;
  double get speed;
  double get aspectRatio;
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(int micros);
  Future<void> setSpeed(double speed);
  Widget buildView();
}

/// [VideoPlayback] backed by the `video_player` plugin (ExoPlayer).
class PluginVideoPlayback extends VideoPlayback {
  VideoPlayerController? _c;

  @override
  Future<void> open(String path) async {
    final c = VideoPlayerController.file(File(path));
    _c = c;
    c.addListener(notifyListeners);
    await c.initialize();
    notifyListeners();
  }

  VideoPlayerValue? get _v => _c?.value;

  @override
  bool get initialized => _v?.isInitialized ?? false;

  @override
  int get positionMicros => _v?.position.inMicroseconds ?? 0;

  @override
  int get durationMicros => _v?.duration.inMicroseconds ?? 0;

  @override
  bool get playing => _v?.isPlaying ?? false;

  @override
  double get speed => _v?.playbackSpeed ?? 1;

  @override
  double get aspectRatio {
    final r = _v?.aspectRatio ?? 16 / 9;
    return r > 0 ? r : 16 / 9;
  }

  @override
  Future<void> play() async => _c?.play();

  @override
  Future<void> pause() async => _c?.pause();

  @override
  Future<void> seekTo(int micros) async =>
      _c?.seekTo(Duration(microseconds: micros.clamp(0, durationMicros)));

  @override
  Future<void> setSpeed(double speed) async => _c?.setPlaybackSpeed(speed);

  @override
  Widget buildView() {
    final c = _c;
    if (c == null || !initialized) return const SizedBox.shrink();
    return VideoPlayer(c);
  }

  @override
  void dispose() {
    _c?.removeListener(notifyListeners);
    _c?.dispose();
    super.dispose();
  }
}
