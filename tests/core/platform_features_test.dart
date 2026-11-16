import 'package:cyclescope/core/platform_features.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/platform/hardware_keys.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android offers volume keys and the recording notification', () {
    final features = PlatformFeatures.of(TargetPlatform.android);
    expect((features.volumeKeys, features.recordingNotification), (true, true));
  });

  test('iOS offers neither volume keys nor the recording notification', () {
    final features = PlatformFeatures.of(TargetPlatform.iOS);
    expect(
      (features.volumeKeys, features.recordingNotification),
      (false, false),
    );
  });

  ProviderContainer containerOn(TargetPlatform platform) {
    final container = ProviderContainer(
      overrides: [
        platformFeaturesProvider.overrideWithValue(
          PlatformFeatures.of(platform),
        ),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(notifications: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('iOS gets silent volume keys and no recording notification', () {
    final container = containerOn(TargetPlatform.iOS);
    expect(container.read(hardwareKeysProvider), isA<SilentHardwareKeys>());
    expect(
      container.read(recordingNotifierProvider),
      isA<SilentRecordingNotifier>(),
    );
  });

  test('android gets volume keys and the recording notification', () {
    final container = containerOn(TargetPlatform.android);
    expect(container.read(hardwareKeysProvider), isA<AndroidHardwareKeys>());
    expect(
      container.read(recordingNotifierProvider),
      isA<AndroidRecordingNotifier>(),
    );
  });
}
