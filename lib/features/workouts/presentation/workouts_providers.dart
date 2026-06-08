import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../data/workouts_repository.dart';
import '../domain/calendar_service.dart';

final workoutsRepositoryProvider = Provider<WorkoutsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final clock = ref.watch(clockProvider);
  return WorkoutsRepository(db, clock);
});

final activeSessionProvider = StreamProvider<WorkoutSessionData?>((ref) {
  return ref.watch(workoutsRepositoryProvider).watchActiveSession();
});

final recentSessionsProvider = StreamProvider<List<WorkoutSessionData>>((ref) {
  return ref.watch(workoutsRepositoryProvider).watchRecentSessions();
});

final exerciseCatalogProvider =
    StreamProvider.family<List<ExerciseCatalogData>, String?>((ref, query) {
  return ref.watch(workoutsRepositoryProvider).watchExercises(query: query);
});

final sessionExercisesProvider =
    StreamProvider.family<List<WorkoutExerciseData>, int>((ref, sessionId) {
  return ref.watch(workoutsRepositoryProvider).watchSessionExercises(sessionId);
});

final setsForWorkoutExerciseProvider =
    StreamProvider.family<List<SetEntryData>, int>((ref, workoutExerciseId) {
  return ref
      .watch(workoutsRepositoryProvider)
      .watchSetsForWorkoutExercise(workoutExerciseId);
});

/// (exerciseId) → [last completed working sets from prior session]
final lastPerformanceProvider =
    FutureProvider.family<List<SetEntryData>, int>((ref, exerciseId) async {
  return ref.watch(workoutsRepositoryProvider).lastPerformanceFor(exerciseId);
});

final recentExerciseIdsProvider = FutureProvider<Set<int>>((ref) async {
  return ref.watch(workoutsRepositoryProvider).getRecentExerciseIds();
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CalendarService(db);
});
