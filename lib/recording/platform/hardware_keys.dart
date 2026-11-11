import 'package:flutter/services.dart';

import '../../core/clock.dart';
import '../domain/key_interpreter.dart';

/// Source of volume-key events while recording.
abstract class HardwareKeys {
  /// Key transitions; only delivered while capture is enabled.
  Stream<KeyEventData> get events;

  /// Enables capture: volume keys no longer change the volume.
  Future<void> setCapture(bool on);
}

/// Android implementation (see `MainActivity.kt`).
///
/// Native code reports how long ago each key event happened, so the Dart side
/// can compute the exact press time on its own monotonic clock.
class AndroidHardwareKeys implements HardwareKeys {
  AndroidHardwareKeys(this.clock);

  final Clock clock;

  static const _methods = MethodChannel('dev.cyclescope/platform');
  static const _events = EventChannel('dev.cyclescope/keys');

  @override
  late final Stream<KeyEventData> events = _events.receiveBroadcastStream().map(
    (raw) {
      final m = Map<String, Object?>.from(raw as Map);
      final age = (m['ageMicros'] as num?)?.toInt() ?? 0;
      return KeyEventData(
        key: m['key'] == 'up' ? VolumeKey.up : VolumeKey.down,
        down: m['action'] == 'down',
        atMicros: clock.nowMicros() - age,
      );
    },
  );

  @override
  Future<void> setCapture(bool on) async {
    try {
      await _methods.invokeMethod<void>('setKeyCapture', on);
    } on MissingPluginException {
      // Not on Android.
    }
  }
}
