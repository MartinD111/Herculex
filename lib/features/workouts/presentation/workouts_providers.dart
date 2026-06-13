import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../data/micro_workouts_repository.dart';
import '../data/templates_repository.dart';
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

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return TemplatesRepository(ref.watch(appDatabaseProvider));
});

final workoutFoldersProvider = StreamProvider<List<WorkoutFolderData>>((ref) {
  return ref.watch(templatesRepositoryProvider).watchFolders();
});

final workoutTemplatesProvider =
    StreamProvider.family<List<WorkoutTemplateData>, int?>((ref, folderId) {
  return ref.watch(templatesRepositoryProvider).watchTemplates(folderId: folderId);
});

final templateExercisesProvider =
    StreamProvider.family<List<TemplateExerciseData>, int>((ref, templateId) {
  return ref.watch(templatesRepositoryProvider).watchTemplateExercises(templateId);
});

// ── V2 logging foundation (Phase 2) ──────────────────────────────────────────

/// Classic vs. Dynamic full-screen workout mode (§14). Session-scoped UI state.
final dynamicWorkoutModeProvider = StateProvider<bool>((_) => false);

final gymsProvider = StreamProvider<List<GymData>>((ref) {
  return ref.watch(gymsRepositoryProvider).watchGyms();
});

final accessoriesProvider = StreamProvider<List<AccessoryData>>((ref) {
  return ref.watch(accessoriesRepositoryProvider).watchAccessories();
});

final bandsProvider = StreamProvider<List<BandData>>((ref) {
  return ref.watch(accessoriesRepositoryProvider).watchBands();
});

final setAccessoriesProvider =
    StreamProvider.family<List<SetAccessoryData>, int>((ref, setEntryId) {
  return ref.watch(accessoriesRepositoryProvider).watchSetAccessories(setEntryId);
});

final setBandsProvider =
    StreamProvider.family<List<SetBandData>, int>((ref, setEntryId) {
  return ref.watch(accessoriesRepositoryProvider).watchSetBands(setEntryId);
});

/// Latest logged bodyweight — snapshotted onto weighted-bodyweight sets (§9).
final latestBodyweightProvider = FutureProvider<double?>((ref) {
  return ref.watch(measurementsRepositoryProvider).latestBodyweightKg();
});

final microWorkoutsRepositoryProvider = Provider<MicroWorkoutsRepository>((ref) {
  return MicroWorkoutsRepository(
      ref.watch(appDatabaseProvider), ref.watch(clockProvider));
});

/// Active micro workouts with today's completion counts (§20).
final microWorkoutsTodayProvider =
    StreamProvider<List<MicroWorkoutStatus>>((ref) {
  return ref.watch(microWorkoutsRepositoryProvider).watchTodayStatus();
});

/// Per-exercise progression override row (§16). Null = no override set.
final exerciseProgressionProvider =
    FutureProvider.family<ExerciseProgressionData?, int>((ref, exerciseId) {
  return ref
      .watch(exerciseProgressionsRepositoryProvider)
      .forExercise(exerciseId);
});
