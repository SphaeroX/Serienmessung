import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../group/data/group_repository.dart';
import '../group/domain/study_group.dart';
import '../recording/data/measurement_repository.dart';
import '../recording/data/run_state_repository.dart';
import '../recording/platform/hardware_keys.dart';
import '../recording/platform/recording_notifier.dart';
import '../settings/presentation/settings_controller.dart';
import '../study/data/study_repository.dart';
import '../study/domain/study.dart';
import 'clock.dart';
import 'database.dart';
import 'platform.dart';

/// The opened app database. Overridden in `main()` and in tests.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(ref.watch(databaseProvider)),
);

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => MeasurementRepository(ref.watch(databaseProvider)),
);

final runStateRepositoryProvider = Provider<RunStateRepository>(
  (ref) => RunStateRepository(ref.watch(databaseProvider)),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.watch(databaseProvider)),
);

/// Groups for the group list. Invalidate after changes.
final groupListProvider = FutureProvider<List<GroupSummary>>(
  (ref) => ref.watch(groupRepositoryProvider).listGroups(),
);

/// Studies for the home screen. Invalidate after changes.
final studyListProvider = FutureProvider<List<StudySummary>>(
  (ref) => ref.watch(studyRepositoryProvider).listStudies(),
);

/// Wall clock for timestamps like "created at" (not for durations).
final wallClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Monotonic clock for all durations. Overridden in `main()` with the
/// Android elapsed-realtime offset and with a fake clock in tests.
final clockProvider = Provider<Clock>((ref) => MonotonicClock());

/// Haptics and wake lock.
final deviceFeedbackProvider = Provider<DeviceFeedback>((ref) {
  final s = ref.watch(settingsProvider);
  return SystemDeviceFeedback(
    vibrate: s.vibration,
    keepScreenOn: s.keepScreenOn,
  );
});

/// Volume keys (Android platform channel).
final hardwareKeysProvider = Provider<HardwareKeys>(
  (ref) => AndroidHardwareKeys(ref.watch(clockProvider)),
);

/// Ongoing notification while recording.
final recordingNotifierProvider = Provider<RecordingNotifier>(
  (ref) => ref.watch(settingsProvider).notifications
      ? AndroidRecordingNotifier()
      : const SilentRecordingNotifier(),
);
