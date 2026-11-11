import 'dart:typed_data';

import 'package:cyclescope/video/domain/frame_cache.dart';
import 'package:cyclescope/video/platform/frame_source.dart';
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

/// 1x1 transparent PNG used as a decoded frame.
final onePixelPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x60,
  0x60,
  0x60,
  0x00,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xA5,
  0xF6,
  0x45,
  0x40,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Frame decoder with a fixed frame rate; records the requested frames.
class FakeFrameSource implements FrameSource {
  FakeFrameSource({this.timing});

  /// Null = decoding not supported.
  final FrameTiming? timing;
  final requests = <(int, int)>[];
  bool closed = false;

  @override
  Future<FrameTiming?> open(String path) async => timing;

  @override
  Future<List<Uint8List>> frames(int first, int count) async {
    requests.add((first, count));
    return List.filled(count, onePixelPng);
  }

  @override
  Future<void> close() async => closed = true;
}
