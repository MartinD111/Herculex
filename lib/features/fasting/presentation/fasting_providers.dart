import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/fasting_repository.dart';
import '../../../data/local/database.dart';

final fastingRepositoryProvider = Provider<FastingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final clock = ref.watch(clockProvider);
  return FastingRepository(db, clock);
});

final activeFastingSessionProvider = StreamProvider<FastingSessionData?>((ref) {
  final repo = ref.watch(fastingRepositoryProvider);
  return repo.watchActiveSession();
});

final fastingHistoryProvider = StreamProvider<List<FastingSessionData>>((ref) {
  final repo = ref.watch(fastingRepositoryProvider);
  return repo.watchHistory();
});

final fastingStreakProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(fastingRepositoryProvider);
  // Watch active session so streak updates when a session ends
  ref.watch(activeFastingSessionProvider);
  return repo.currentStreak();
});

final fastingAverageEatingWindowProvider = FutureProvider<double>((ref) {
  final repo = ref.watch(fastingRepositoryProvider);
  // Watch active session so stats update when a session ends
  ref.watch(activeFastingSessionProvider);
  return repo.averageEatingWindow(30);
});

/// A timer ticker stream that emits the elapsed duration since the active fast started,
/// updated every second. Emits null if no active fast is running.
final fastingTimerTickerProvider = StreamProvider<Duration?>((ref) {
  final activeAsync = ref.watch(activeFastingSessionProvider);
  final active = activeAsync.asData?.value;
  if (active == null) {
    return Stream.value(null);
  }

  final clock = ref.watch(clockProvider);

  Stream<Duration?> ticker() async* {
    yield clock.now().difference(active.startedAt);
    yield* Stream.periodic(const Duration(seconds: 1), (_) {
      return clock.now().difference(active.startedAt);
    });
  }

  return ticker();
});
