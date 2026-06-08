import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../data/local/database.dart';

class ProgramsRepository {
  final AppDatabase _db;
  final Clock _clock;

  ProgramsRepository(this._db, this._clock);

  // ── Template CRUD ────────────────────────────────────────────────────────

  Future<int> createProgram({
    required String name,
    required String? description,
    required int weeks,
    required String type, // rotating | block
    required String progressionStrategy, // volume | intensity | dynamic
  }) async {
    return _db.transaction(() async {
      final programId = await _db.into(_db.programs).insert(
            ProgramsCompanion.insert(
              name: name,
              description: Value(description),
              weeks: Value(weeks),
              type: Value(type),
              progressionStrategy: Value(progressionStrategy),
              createdByUser: const Value(true),
              archived: const Value(false),
            ),
          );

      // Materialise default template weeks
      final totalWeeks = type == 'rotating' ? 1 : weeks;
      for (int i = 0; i < totalWeeks; i++) {
        await _db.into(_db.programWeeks).insert(
              ProgramWeeksCompanion.insert(
                programId: programId,
                weekIndex: i,
                adjustmentFactor: const Value(1.0),
              ),
            );
      }

      return programId;
    });
  }

  Future<List<ProgramData>> getActivePrograms() {
    return (_db.select(_db.programs)..where((t) => t.archived.equals(false))).get();
  }

  Future<ProgramData?> getProgram(int id) {
    return (_db.select(_db.programs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<ProgramWeekData>> getProgramWeeks(int programId) {
    return (_db.select(_db.programWeeks)..where((t) => t.programId.equals(programId))).get();
  }

  Future<List<ProgramDayData>> getProgramDaysForWeek(int weekId) {
    return (_db.select(_db.programDays)..where((t) => t.programWeekId.equals(weekId))).get();
  }

  Future<int> addProgramDay({
    required int programWeekId,
    required int dayOfWeek,
    required String name,
  }) {
    return _db.into(_db.programDays).insert(
          ProgramDaysCompanion.insert(
            programWeekId: programWeekId,
            dayOfWeek: dayOfWeek,
            name: name,
          ),
        );
  }

  Future<int> addExerciseToProgramDay({
    required int programDayId,
    required int exerciseId,
    required int targetSets,
    int? targetRepsMin,
    int? targetRepsMax,
    int? targetRpe,
    required int orderIndex,
  }) {
    return _db.into(_db.programDayExercises).insert(
          ProgramDayExercisesCompanion.insert(
            programDayId: programDayId,
            exerciseId: exerciseId,
            targetSets: Value(targetSets),
            targetRepsMin: Value(targetRepsMin),
            targetRepsMax: Value(targetRepsMax),
            targetRpe: Value(targetRpe),
            orderIndex: orderIndex,
          ),
        );
  }

  Future<List<ProgramDayExerciseData>> getExercisesForDay(int programDayId) {
    return (_db.select(_db.programDayExercises)
          ..where((t) => t.programDayId.equals(programDayId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
  }

  // ── Scheduler Engine ─────────────────────────────────────────────────────

  Future<void> materializeProgram(int programId, DateTime startDate) async {
    final program = await getProgram(programId);
    if (program == null) return;

    await _db.transaction(() async {
      // Clear existing planned scheduled workouts
      await (_db.delete(_db.scheduledWorkouts)
            ..where((t) => t.status.equals('planned')))
          .go();

      final weeks = await getProgramWeeks(programId);
      final duration = program.weeks;

      for (int w = 0; w < duration; w++) {
        // For rotating plans, we cycle through the single template week (index 0).
        // For block plans, we map week-by-week.
        final templateWeek = program.type == 'rotating' 
            ? weeks.first 
            : weeks.firstWhere((week) => week.weekIndex == w, orElse: () => weeks.first);

        final days = await getProgramDaysForWeek(templateWeek.id);
        final weekStart = startDate.add(Duration(days: w * 7));

        for (final day in days) {
          final workoutDate = weekStart.add(Duration(days: day.dayOfWeek - 1));
          final dateIso = _formatDateIso(workoutDate);

          await _db.into(_db.scheduledWorkouts).insert(
                ScheduledWorkoutsCompanion.insert(
                  dateIso: dateIso,
                  programDayId: day.id,
                  status: const Value('planned'),
                ),
              );
        }
      }
    });
  }

  Future<void> moveWorkout(int scheduleId, DateTime newDate) async {
    await (_db.update(_db.scheduledWorkouts)..where((t) => t.id.equals(scheduleId))).write(
      ScheduledWorkoutsCompanion(
        dateIso: Value(_formatDateIso(newDate)),
        status: const Value('moved'),
      ),
    );
  }

  // ── Fatigue Conflict Checking ──

  /// Flags a fatigue conflict if workouts hitting the same primary muscle group
  /// are scheduled within 48 hours of each other.
  Future<List<Map<String, dynamic>>> detectRecoveryConflicts() async {
    final scheduledList = await _db.select(_db.scheduledWorkouts).get();
    final conflicts = <Map<String, dynamic>>[];

    for (int i = 0; i < scheduledList.length; i++) {
      for (int j = i + 1; j < scheduledList.length; j++) {
        final w1 = scheduledList[i];
        final w2 = scheduledList[j];

        final d1 = DateTime.parse(w1.dateIso);
        final d2 = DateTime.parse(w2.dateIso);
        final diffHrs = d1.difference(d2).inHours.abs();

        if (diffHrs <= 48) {
          final muscles1 = await _getMuscleGroupsForScheduledWorkout(w1.id);
          final muscles2 = await _getMuscleGroupsForScheduledWorkout(w2.id);

          final overlaps = muscles1.intersection(muscles2);
          if (overlaps.isNotEmpty) {
            conflicts.add({
              'scheduledWorkoutId1': w1.id,
              'scheduledWorkoutId2': w2.id,
              'muscles': overlaps.toList(),
              'message': 'Fatigue conflict: Same muscle group (${overlaps.join(", ")}) hit within 48h.',
            });
          }
        }
      }
    }
    return conflicts;
  }

  Future<Set<String>> _getMuscleGroupsForScheduledWorkout(int scheduleId) async {
    final scheduled = await (_db.select(_db.scheduledWorkouts)..where((t) => t.id.equals(scheduleId))).getSingle();
    final exercises = await getExercisesForDay(scheduled.programDayId);
    
    final muscles = <String>{};
    for (final ex in exercises) {
      final catalog = await (_db.select(_db.exerciseCatalog)..where((t) => t.id.equals(ex.exerciseId))).getSingleOrNull();
      if (catalog != null) {
        muscles.add(catalog.primaryMuscle);
      }
    }
    return muscles;
  }

  // ── External Events / Deload Trips ──

  Future<int> addExternalEvent({
    required DateTime from,
    required DateTime to,
    required String type, // vacation | deload | rest | high_activity
    String? notes,
  }) async {
    final eventId = await _db.into(_db.externalEvents).insert(
          ExternalEventsCompanion.insert(
            dateFromIso: _formatDateIso(from),
            dateToIso: _formatDateIso(to),
            type: type,
            notes: Value(notes),
          ),
        );

    // Auto-adjust overlapping scheduled workouts (skip / volume reduction)
    await _applyEventAdjustments();

    return eventId;
  }

  Future<void> _applyEventAdjustments() async {
    final events = await _db.select(_db.externalEvents).get();
    final workouts = await _db.select(_db.scheduledWorkouts).get();

    for (final w in workouts) {
      final wDate = DateTime.parse(w.dateIso);
      for (final e in events) {
        final eFrom = DateTime.parse(e.dateFromIso);
        final eTo = DateTime.parse(e.dateToIso);

        if (wDate.isAfter(eFrom.subtract(const Duration(seconds: 1))) && 
            wDate.isBefore(eTo.add(const Duration(days: 1)))) {
          if (e.type == 'vacation' || e.type == 'rest') {
            // Shift planned workouts downstream or mark skipped
            await (_db.update(_db.scheduledWorkouts)..where((t) => t.id.equals(w.id))).write(
              const ScheduledWorkoutsCompanion(
                status: Value('skipped'),
              ),
            );
          }
        }
      }
    }
  }

  String _formatDateIso(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
}
