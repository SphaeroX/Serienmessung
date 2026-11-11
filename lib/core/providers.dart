import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recording/data/measurement_repository.dart';
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
final deviceFeedbackProvider = Provider<DeviceFeedback>(
  (ref) => SystemDeviceFeedback(),
);
