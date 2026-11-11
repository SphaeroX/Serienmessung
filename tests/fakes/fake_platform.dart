import 'package:cyclescope/core/platform.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

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

List<Override> fakePlatformOverrides({FakeDeviceFeedback? feedback}) => [
  deviceFeedbackProvider.overrideWithValue(feedback ?? FakeDeviceFeedback()),
];
