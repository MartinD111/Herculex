import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../data/local/database.dart';

/// Today's scheduled workout resolved with its program-day name and exercise
/// count, for the dashboard smart launcher (§18).
class TodaysScheduledWorkout {
  final ScheduledWorkoutData schedule;
  final ProgramDayData programDay;
  final int exerciseCount;

  const TodaysScheduledWorkout({
    required this.schedule,
    required this.programDay,
    required this.exerciseCount,
  });

  bool get isDone => schedule.status == 'done' || schedule.completedSessionId != null;
}

/// Smart workout launcher (§18): reads the day's scheduled workout and starts
/// a real session pre-populated from the program day's prescribed exercises.
class ScheduledWorkoutService {
  final AppDatabase _db;
  final Clock _clock;

  ScheduledWorkoutService(this._db, this._clock);

  static String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The (first) workout scheduled for today, or null when nothing is planned.
  Future<TodaysScheduledWorkout?> todaysWorkout() async {
    final iso = _dateIso(_clock.now());
    final schedule = await (_db.select(_db.scheduledWorkouts)
          ..where((t) => t.dateIso.equals(iso))
          ..limit(1))
        .getSingleOrNull();
    if (schedule == null) return null;

    final day = await (_db.select(_db.programDays)
          ..where((t) => t.id.equals(schedule.programDayId)))
        .getSingleOrNull();
    if (day == null) return null;

    final exercises = await (_db.select(_db.programDayExercises)
          ..where((t) => t.programDayId.equals(day.id)))
        .get();

    return TodaysScheduledWorkout(
      schedule: schedule,
      programDay: day,
      exerciseCount: exercises.length,
    );
  }

  /// Starts a session pre-populated from the scheduled day's exercises and
  /// links it back to the schedule (status → done on finish). Returns the new
  /// session id. [gymId] tags the session like a normal start.
  Future<int> startScheduledWorkout(
    TodaysScheduledWorkout today, {
    int? gymId,
  }) async {
    return _db.transaction(() async {
      final sessionId = await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              startedAt: _clock.now(),
              notes: Value(today.programDay.name),
              gymId: Value(gymId),
            ),
          );

      final exercises = await (_db.select(_db.programDayExercises)
            ..where((t) => t.programDayId.equals(today.programDay.id))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

      for (final (i, pde) in exercises.indexed) {
        final catalogRow = await (_db.select(_db.exerciseCatalog)
              ..where((t) => t.id.equals(pde.exerciseId)))
            .getSingleOrNull();
        await _db.into(_db.workoutExercises).insert(
              WorkoutExercisesCompanion.insert(
                sessionId: sessionId,
                exerciseId: pde.exerciseId,
                orderIndex: i,
                targetRestSeconds:
                    Value(catalogRow?.defaultRestSeconds),
                equipmentVariant: Value(pde.equipmentVariant),
              ),
            );
      }

      // Link schedule → session so it shows as in-progress / done.
      await (_db.update(_db.scheduledWorkouts)
            ..where((t) => t.id.equals(today.schedule.id)))
          .write(ScheduledWorkoutsCompanion(
        completedSessionId: Value(sessionId),
        status: const Value('done'),
      ));

      return sessionId;
    });
  }
}
