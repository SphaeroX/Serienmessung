import 'dart:async';

import 'package:cyclescope/core/platform.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/url_opener.dart';
import 'package:cyclescope/recording/domain/key_interpreter.dart';
import 'package:cyclescope/recording/platform/hardware_keys.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_video_files.dart';

/// Records platform calls instead of touching the device.
class FakeDeviceFeedback implements DeviceFeedback {
  final events = <String>[];
  bool wakeLock = false;

  @override
  Future<void> stepChanged() async => events.add('step');

  @override
  Future<void> cycleChanged() async => events.add('cycle');

  @override
  Future<void> specialStarted() async => events.add('special');

  @override
  Future<void> setKeepScreenOn(bool on) async => wakeLock = on;
}

/// Volume keys driven by the test.
class FakeHardwareKeys implements HardwareKeys {
  final _controller = StreamController<KeyEventData>.broadcast(sync: true);
  bool capturing = false;

  @override
  Stream<KeyEventData> get events => _controller.stream;

  @override
  Future<void> setCapture(bool on) async => capturing = on;

  void emit(VolumeKey key, {required bool down, required int at}) =>
      _controller.add(KeyEventData(key: key, down: down, atMicros: at));

  /// Short press: key down and up at the same time.
  void press(VolumeKey key, {required int at}) {
    emit(key, down: true, at: at);
    emit(key, down: false, at: at);
  }
}

/// Captures the last shown notification.
class FakeRecordingNotifier implements RecordingNotifier {
  RecordingNotice? shown;
  final _actions = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get actions => _actions.stream;

  @override
  Future<void> show(RecordingNotice notice) async => shown = notice;

  @override
  Future<void> hide() async => shown = null;

  void press(String action) => _actions.add(action);
}

/// Records opened links instead of starting a browser.
class FakeUrlOpener implements UrlOpener {
  final opened = <Uri>[];

  /// What [open] reports back.
  bool result = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return result;
  }
}

List<Override> fakePlatformOverrides({
  FakeDeviceFeedback? feedback,
  FakeHardwareKeys? keys,
  FakeRecordingNotifier? notifier,
  FakeVideoFiles? videoFiles,
  FakeUrlOpener? urlOpener,
}) => [
  recordingNotifierProvider.overrideWithValue(
    notifier ?? FakeRecordingNotifier(),
  ),
  deviceFeedbackProvider.overrideWithValue(feedback ?? FakeDeviceFeedback()),
  hardwareKeysProvider.overrideWithValue(keys ?? FakeHardwareKeys()),
  // Tests never delete real files.
  videoFilesProvider.overrideWithValue(videoFiles ?? FakeVideoFiles()),
  urlOpenerProvider.overrideWithValue(urlOpener ?? FakeUrlOpener()),
];
