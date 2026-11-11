import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Haptic feedback and screen wake lock, behind an interface for tests.
abstract class DeviceFeedback {
  Future<void> stepChanged();
  Future<void> cycleChanged();
  Future<void> specialStarted();
  Future<void> setKeepScreenOn(bool on);
}

/// Real implementation using the system haptics and wakelock_plus.
class SystemDeviceFeedback implements DeviceFeedback {
  SystemDeviceFeedback({this.vibrate = true, this.keepScreenOn = true});

  final bool vibrate;
  final bool keepScreenOn;

  @override
  Future<void> stepChanged() async {
    if (vibrate) await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> cycleChanged() async {
    if (!vibrate) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> specialStarted() async {
    if (vibrate) await HapticFeedback.vibrate();
  }

  @override
  Future<void> setKeepScreenOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on && keepScreenOn);
    } on Object {
      // Not available on this platform; ignore.
    }
  }
}
