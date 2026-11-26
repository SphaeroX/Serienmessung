import 'package:flutter/services.dart';

/// The platform time that keeps counting during device sleep (µs since boot;
/// `SystemClock.elapsedRealtime` on Android, `CLOCK_MONOTONIC_RAW` on iOS).
abstract class PlatformTime {
  /// Null where the platform cannot tell.
  Future<int?> readMicros();
}

/// Reads the platform time over `dev.cyclescope/platform`.
class ChannelPlatformTime implements PlatformTime {
  const ChannelPlatformTime();

  @override
  Future<int?> readMicros() => readElapsedRealtimeMicros();
}

/// Reads the platform time that keeps counting during sleep (µs;
/// `SystemClock.elapsedRealtime` on Android, `CLOCK_MONOTONIC_RAW` on iOS)
/// so the monotonic clock survives app restarts. Returns null where
/// unavailable.
Future<int?> readElapsedRealtimeMicros() async {
  try {
    final v = await const MethodChannel('dev.cyclescope/platform')
        .invokeMethod<int>('elapsedRealtimeMicros');
    return v;
  } on Object {
    return null;
  }
}
