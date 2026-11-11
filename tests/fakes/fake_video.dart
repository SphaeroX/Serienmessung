import 'package:cyclescope/video/platform/video_picker.dart';
import 'package:cyclescope/video/platform/video_playback.dart';
import 'package:flutter/widgets.dart';

/// Player whose position is set by the test.
class FakeVideoPlayback extends VideoPlayback {
  String? openedPath;
  int position = 0;
  int duration = 60 * 1000000;
  bool isPlaying = false;
  double currentSpeed = 1;
  final seeks = <int>[];

  @override
  Future<void> open(String path) async {
    openedPath = path;
    notifyListeners();
  }

  @override
  bool get initialized => openedPath != null;

  @override
  int get positionMicros => position;

  @override
  int get durationMicros => duration;

  @override
  bool get playing => isPlaying;

  @override
  double get speed => currentSpeed;

  @override
  double get aspectRatio => 16 / 9;

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(int micros) async {
    seeks.add(micros);
    position = micros.clamp(0, duration);
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double speed) async {
    currentSpeed = speed;
    notifyListeners();
  }

  void moveTo(int micros) {
    position = micros;
    notifyListeners();
  }

  @override
  Widget buildView() => const SizedBox.expand(key: Key('fakeVideo'));
}

/// Returns a fixed path instead of opening a file dialog.
class FakeVideoPicker implements VideoPicker {
  FakeVideoPicker([this.path = 'fake:video.mp4']);

  final String? path;

  @override
  Future<String?> pickAndCopy({required int studyId}) async => path;
}
