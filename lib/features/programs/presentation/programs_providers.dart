import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../app/providers.dart';
import '../data/programs_repository.dart';
import '../data/rotations_repository.dart';
import '../../../data/local/database.dart';

final programsRepositoryProvider = Provider<ProgramsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final clock = ref.watch(clockProvider);
  return ProgramsRepository(db, clock);
});

final activeProgramsProvider = FutureProvider<List<ProgramData>>((ref) {
  final repo = ref.watch(programsRepositoryProvider);
  return repo.getActivePrograms();
});

final scheduledWorkoutsProvider = StreamProvider<List<ScheduledWorkoutData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.scheduledWorkouts)
        ..orderBy([(t) => OrderingTerm(expression: t.dateIso)]))
      .watch();
});

final externalEventsProvider = StreamProvider<List<ExternalEventData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.externalEvents).watch();
});

final recoveryConflictsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(programsRepositoryProvider);
  // Re-run whenever workouts change
  ref.watch(scheduledWorkoutsProvider);
  return repo.detectRecoveryConflicts();
});

final rotationsRepositoryProvider = Provider<RotationsRepository>((ref) {
  return RotationsRepository(ref.watch(appDatabaseProvider));
});

final rotationPoolsProvider = StreamProvider<List<ExerciseRotationData>>((ref) {
  return ref.watch(rotationsRepositoryProvider).watchRotations();
});

final rotationMembersProvider =
    StreamProvider.family<List<RotationMemberData>, int>((ref, rotationId) {
  return ref.watch(rotationsRepositoryProvider).watchMembers(rotationId);
});
