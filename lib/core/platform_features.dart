import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recording aids only some platforms offer.
class PlatformFeatures {
  const PlatformFeatures({
    required this.volumeKeys,
    required this.recordingNotification,
  });

  /// iOS permits no volume key capture (App Review guideline 2.5.9) and has
  /// no ongoing notification, so only Android offers both.
  factory PlatformFeatures.of(TargetPlatform platform) {
    final isAndroid = platform == TargetPlatform.android;
    return PlatformFeatures(
      volumeKeys: isAndroid,
      recordingNotification: isAndroid,
    );
  }

  final bool volumeKeys;
  final bool recordingNotification;
}

/// Features of the platform the app runs on.
final platformFeaturesProvider = Provider<PlatformFeatures>(
  (ref) => PlatformFeatures.of(defaultTargetPlatform),
);
