import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herculex/core/clock.dart';
import 'package:herculex/data/local/database.dart';
import 'package:herculex/features/programs/data/program_csv_io.dart';
import 'package:herculex/features/programs/data/rotations_repository.dart';
import 'package:herculex/features/programs/domain/exercise_rotation.dart';
import 'package:herculex/features/programs/domain/periodization.dart';
import 'package:herculex/features/programs/domain/program_csv.dart';
import 'package:herculex/features/workouts/data/micro_workouts_repository.dart';

class _FixedClock implements Clock {
  DateTime fixed;
  _FixedClock(this.fixed);
  @override
  DateTime now() => fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Periodization', () {
    test('linear ramps intensity and deloads every 4th week', () {
      final plan = Periodization.plan(PeriodizationModel.linear, 8);
      expect(plan, hasLength(8));
      expect(plan[1].intensityFactor, greaterThan(plan[0].intensityFactor));
      expect(plan[3].isDeload, isTrue);
      expect(plan[7].isDeload, isTrue);
      expect(plan[3].volumeFactor, lessThan(plan[0].volumeFactor));
    });

    test('block splits accumulation → transmutation → realization', () {
      final plan = Periodization.plan(PeriodizationModel.block, 10);
      expect(plan.first.blockPhase, 'accumulation');
      expect(plan.last.blockPhase, 'realization');
      expect(plan.map((w) => w.blockPhase).toSet(),
          {'accumulation', 'transmutation', 'realization'});
      // Accumulation: more volume, less intensity than realization.
      expect(plan.first.volumeFactor, greaterThan(plan.last.volumeFactor));
      expect(plan.first.intensityFactor, lessThan(plan.last.intensityFactor));
    });

    test('max effort holds top intensity and protects CNS every 4th week', () {
      final plan = Periodization.plan(PeriodizationModel.maxEffort, 8);
      expect(plan[0].intensityFactor, 1.0);
      expect(plan[3].isDeload, isTrue);
    });

    test('none is flat', () {
      final plan = Periodization.plan(PeriodizationModel.none, 4);
      expect(plan.every((w) => w.intensityFactor == 1 && w.volumeFactor == 1),
          isTrue);
    });
  });

  group('ExerciseRotation', () {
    test('rotates every N weeks and wraps around the pool', () {
      // 3 exercises, rotate every 2 weeks, 8-week program:
      expect(
        ExerciseRotation.assignments(
            weeks: 8, memberCount: 3, rotateEveryWeeks: 2),
        [0, 0, 1, 1, 2, 2, 0, 0],
      );
    });

    test('weekly rotation with 2 members alternates', () {
      expect(
        ExerciseRotation.assignments(
            weeks: 4, memberCount: 2, rotateEveryWeeks: 1),
        [0, 1, 0, 1],
      );
    });
  });

  group('ProgramCsv codec', () {
    test('encode → decode round-trips', () {
      const doc = ProgramCsvDocument(
        name: 'PPL, Heavy',
        weeks: 4,
        periodizationModel: 'linear',
        rows: [
          ProgramCsvRow(
            weekIndex: 0,
            dayOfWeek: 1,
            dayName: 'Push',
            exerciseName: 'Bench Press',
            sets: 3,
            repsMin: 8,
            repsMax: 12,
            rpe: 8,
            setType: 'standard',
            percentOf1Rm: 75,
            equipmentVariant: 'barbell',
          ),
        ],
      );
      final decoded = ProgramCsv.decode(ProgramCsv.encode(doc));
      expect(decoded.name, 'PPL, Heavy'); // comma survives quoting
      expect(decoded.weeks, 4);
      expect(decoded.periodizationModel, 'linear');
      expect(decoded.rows.single.exerciseName, 'Bench Press');
      expect(decoded.rows.single.percentOf1Rm, 75);
      expect(decoded.rows.single.equipmentVariant, 'barbell');
    });

    test('rejects malformed input with readable errors', () {
      expect(() => ProgramCsv.decode(''), throwsA(isA<ProgramCsvFormatException>()));
      expect(() => ProgramCsv.decode('nonsense,row'),
          throwsA(isA<ProgramCsvFormatException>()));
      expect(
        () => ProgramCsv.decode('program,X,4,linear\n0,9,Push,Bench,3'),
        throwsA(isA<ProgramCsvFormatException>()), // dayOfWeek out of range
      );
    });
  });

  group('Database-backed Phase 4', () {
    late AppDatabase db;
    late _FixedClock clock;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement('PRAGMA foreign_keys = ON');
      clock = _FixedClock(DateTime(2026, 6, 12, 9));
    });

    tearDown(() => db.close());

    Future<int> exerciseIdByName(String name) async {
      final row = await (db.select(db.exerciseCatalog)
            ..where((t) => t.name.equals(name))
            ..limit(1))
          .getSingleOrNull();
      if (row != null) return row.id;
      return db.into(db.exerciseCatalog).insert(
            ExerciseCatalogCompanion.insert(
              name: name,
              primaryMuscle: 'Chest',
              equipment: 'Barbell',
              mechanics: 'compound',
              force: 'push',
              plane: 'horizontal',
            ),
          );
    }

    test('rotation resolves the active exercise per program week', () async {
      final repo = RotationsRepository(db);
      final a = await exerciseIdByName('Test Close-Grip Bench');
      final b = await exerciseIdByName('Test Floor Press');
      final c = await exerciseIdByName('Test Paused OHP');
      final rotationId = await repo.createRotation(
        name: 'ME Press',
        rotateEveryWeeks: 1,
        exerciseIds: [a, b, c],
      );

      final week0 =
          await repo.activeExerciseFor(rotationId: rotationId, weekIndex: 0);
      final week1 =
          await repo.activeExerciseFor(rotationId: rotationId, weekIndex: 1);
      final week3 =
          await repo.activeExerciseFor(rotationId: rotationId, weekIndex: 3);
      expect(week0!.id, a);
      expect(week1!.id, b);
      expect(week3!.id, a); // wrapped around
    });

    test('micro workout completion writes a real session + completed set',
        () async {
      final repo = MicroWorkoutsRepository(db, clock);
      final pushups = await exerciseIdByName('Test Pushup');
      final id = await repo.create(
          name: '50 Pushups', exerciseId: pushups, targetReps: 50, timesPerDay: 3);
      final micro = await (db.select(db.microWorkouts)
            ..where((t) => t.id.equals(id)))
          .getSingle();

      await repo.logCompletion(micro, bodyweightKg: 80);
      clock.fixed = clock.fixed.add(const Duration(hours: 3));
      await repo.logCompletion(micro, reps: 40);

      final sessions = await (db.select(db.workoutSessions)
            ..where((t) => t.microWorkoutId.equals(id)))
          .get();
      expect(sessions, hasLength(2));
      expect(sessions.every((s) => s.endedAt != null), isTrue);

      final sets = await db.select(db.setEntries).get();
      expect(sets, hasLength(2));
      expect(sets.first.reps, 50);
      expect(sets.first.bodyweightKg, 80);
      expect(sets.last.reps, 40);
      expect(sets.every((s) => s.isCompleted), isTrue);

      final counts = await repo.completionsOn(clock.now());
      expect(counts[id], 2);
    });

    test('CSV import creates program with periodized weeks; export round-trips',
        () async {
      await exerciseIdByName('Test Bench Press');
      await exerciseIdByName('Test Squat');
      final io = ProgramCsvIo(db);

      const csv = '''
program,Test Block,4,block
week,dayOfWeek,dayName,exercise,sets,repsMin,repsMax,rpe,setType,percent1Rm,equipment
0,1,Upper,Test Bench Press,4,6,8,8,standard,75,barbell
0,3,Lower,Test Squat,5,5,5,9,pause,80,barbell
1,1,Upper,Test Bench Press,4,6,8,8,standard,77.5,barbell
''';
      final programId = await io.importProgram(csv);

      final program = await (db.select(db.programs)
            ..where((t) => t.id.equals(programId)))
          .getSingle();
      expect(program.periodizationModel, 'block');
      expect(program.weeks, 4);

      final weeks = await (db.select(db.programWeeks)
            ..where((t) => t.programId.equals(programId)))
          .get();
      expect(weeks, hasLength(4));
      expect(weeks.first.blockPhase, 'accumulation');
      expect(weeks.last.blockPhase, 'realization');

      final exported = await io.exportProgram(programId);
      final reDecoded = ProgramCsv.decode(exported);
      expect(reDecoded.name, 'Test Block');
      expect(reDecoded.rows, hasLength(3));
      expect(
          reDecoded.rows.any((r) =>
              r.exerciseName == 'Test Squat' &&
              r.setType == 'pause' &&
              r.percentOf1Rm == 80),
          isTrue);
    });

    test('CSV import rejects unknown exercise names', () async {
      final io = ProgramCsvIo(db);
      const csv = '''
program,Bad,2,none
0,1,Day,Totally Unknown Exercise,3,8,12,,,,
''';
      expect(
        () => io.importProgram(csv),
        throwsA(predicate((e) =>
            e is ProgramCsvFormatException &&
            e.message.contains('Totally Unknown Exercise'))),
      );
    });
  });
}
