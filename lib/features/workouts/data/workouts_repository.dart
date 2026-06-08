import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../data/local/database.dart';

/// Single facade over the workout tables. UI never touches Drift directly —
/// it goes through this. Keeps queries co-located and swappable later.
class WorkoutsRepository {
  final AppDatabase _db;
  final Clock _clock;

  WorkoutsRepository(this._db, this._clock);

  // ── Exercise catalog ───────────────────────────────────────────────────

  Stream<List<ExerciseCatalogData>> watchExercises({String? query}) {
    final q = _db.select(_db.exerciseCatalog)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      q.where((t) => t.name.like(like) | t.primaryMuscle.like(like));
    }
    return q.watch();
  }

  Future<ExerciseCatalogData> createCustomExercise({
    required String name,
    required String primaryMuscle,
    required String equipment,
    required String mechanics,
    required String force,
    required String plane,
    int defaultRestSeconds = 120,
  }) async {
    final id = await _db.into(_db.exerciseCatalog).insert(
          ExerciseCatalogCompanion.insert(
            name: name,
            primaryMuscle: primaryMuscle,
            equipment: equipment,
            mechanics: mechanics,
            force: force,
            plane: plane,
            defaultRestSeconds: Value(defaultRestSeconds),
            isCustom: const Value(true),
          ),
        );
    return (_db.select(_db.exerciseCatalog)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  // ── Sessions ───────────────────────────────────────────────────────────

  /// Returns the session id of the in-progress workout, if any.
  Stream<WorkoutSessionData?> watchActiveSession() {
    return (_db.select(_db.workoutSessions)
          ..where((t) => t.endedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<int> startSession({String? notes}) async {
    return _db.into(_db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            startedAt: _clock.now(),
            notes: Value(notes),
          ),
        );
  }

  Future<void> endSession(int sessionId, {int? sessionRpe}) async {
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      endedAt: Value(_clock.now()),
      sessionRpe: Value(sessionRpe),
    ));
  }

  Future<void> deleteSession(int sessionId) async {
    await (_db.delete(_db.workoutSessions)..where((t) => t.id.equals(sessionId))).go();
  }

  Stream<List<WorkoutSessionData>> watchRecentSessions({int limit = 25}) {
    return (_db.select(_db.workoutSessions)
          ..where((t) => t.endedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }

  // ── Session exercises + sets ───────────────────────────────────────────

  Stream<List<WorkoutExerciseData>> watchSessionExercises(int sessionId) {
    return (_db.select(_db.workoutExercises)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .watch();
  }

  Stream<List<SetEntryData>> watchSetsForWorkoutExercise(int workoutExerciseId) {
    return (_db.select(_db.setEntries)
          ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .watch();
  }

  Future<int> addExerciseToSession({
    required int sessionId,
    required int exerciseId,
  }) async {
    final existing = await (_db.select(_db.workoutExercises)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    final nextIndex = existing.length;

    final exercise = await (_db.select(_db.exerciseCatalog)
          ..where((t) => t.id.equals(exerciseId)))
        .getSingle();

    return _db.into(_db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            orderIndex: nextIndex,
            targetRestSeconds: Value(exercise.defaultRestSeconds),
          ),
        );
  }

  Future<void> removeWorkoutExercise(int workoutExerciseId) async {
    await (_db.delete(_db.workoutExercises)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .go();
  }

  Future<void> substituteExercise({
    required int workoutExerciseId,
    required int newExerciseId,
  }) async {
    await (_db.update(_db.workoutExercises)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(WorkoutExercisesCompanion(
          exerciseId: Value(newExerciseId),
        ));
  }

  // ── Sets ───────────────────────────────────────────────────────────────

  Future<int> addSet({
    required int workoutExerciseId,
    required double weightKg,
    required int reps,
    int? rpeX10,
    bool isWarmup = false,
  }) async {
    final existing = await (_db.select(_db.setEntries)
          ..where((t) => t.workoutExerciseId.equals(workoutExerciseId)))
        .get();
    final nextIndex = existing.length;
    return _db.into(_db.setEntries).insert(
          SetEntriesCompanion.insert(
            workoutExerciseId: workoutExerciseId,
            setIndex: nextIndex,
            weightKg: weightKg,
            reps: reps,
            rpeX10: Value(rpeX10),
            isWarmup: Value(isWarmup),
          ),
        );
  }

  Future<void> updateSet({
    required int setId,
    double? weightKg,
    int? reps,
    int? rpeX10,
    bool? isWarmup,
    bool? isCompleted,
  }) async {
    await (_db.update(_db.setEntries)..where((t) => t.id.equals(setId))).write(
      SetEntriesCompanion(
        weightKg: weightKg == null ? const Value.absent() : Value(weightKg),
        reps: reps == null ? const Value.absent() : Value(reps),
        rpeX10: rpeX10 == null ? const Value.absent() : Value(rpeX10),
        isWarmup: isWarmup == null ? const Value.absent() : Value(isWarmup),
        isCompleted: isCompleted == null ? const Value.absent() : Value(isCompleted),
        completedAt: isCompleted == true ? Value(_clock.now()) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteSet(int setId) async {
    await (_db.delete(_db.setEntries)..where((t) => t.id.equals(setId))).go();
  }

  // ── Performance lookups ────────────────────────────────────────────────

  /// All sets from the most recent *completed* session that included this exercise.
  /// Used for the "last time" hint shown under the active exercise card.
  Future<List<SetEntryData>> lastPerformanceFor(int exerciseId) async {
    final priorSessions = await (_db.selectOnly(_db.workoutExercises, distinct: true)
          ..addColumns([_db.workoutExercises.sessionId])
          ..join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.workoutExercises.sessionId),
            ),
          ])
          ..where(_db.workoutExercises.exerciseId.equals(exerciseId) &
              _db.workoutSessions.endedAt.isNotNull())
          ..orderBy([
            OrderingTerm(expression: _db.workoutSessions.startedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();

    if (priorSessions.isEmpty) return const [];
    final sessionId = priorSessions.first.read(_db.workoutExercises.sessionId)!;

    final priorWorkoutExercises = await (_db.select(_db.workoutExercises)
          ..where((t) =>
              t.sessionId.equals(sessionId) & t.exerciseId.equals(exerciseId)))
        .get();
    if (priorWorkoutExercises.isEmpty) return const [];

    return (_db.select(_db.setEntries)
          ..where((t) =>
              t.workoutExerciseId.equals(priorWorkoutExercises.first.id) &
              t.isCompleted.equals(true) &
              t.isWarmup.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
  }

  Future<Set<int>> getRecentExerciseIds() async {
    final recent = await (_db.selectOnly(_db.workoutExercises, distinct: true)
          ..addColumns([_db.workoutExercises.exerciseId])
          ..join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.workoutExercises.sessionId),
            ),
          ])
          ..where(_db.workoutSessions.endedAt.isNotNull())
          ..orderBy([
            OrderingTerm(expression: _db.workoutSessions.startedAt, mode: OrderingMode.desc),
          ])
          ..limit(50))
        .get();
    return recent.map((row) => row.read(_db.workoutExercises.exerciseId)!).toSet();
  }
}
