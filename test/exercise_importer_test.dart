import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herculex/core/clock.dart';
import 'package:herculex/data/local/database.dart';
import 'package:herculex/data/local/exercise_importer.dart';
import 'package:herculex/features/workouts/data/workouts_repository.dart';

final _sample = jsonEncode([
  {
    'name': 'Conventional Deadlift',
    'aka': ['Deads', 'Deadlift'],
    'category': 'powerlifting',
    'movementPattern': 'hinge',
    'modality': 'barbell',
    'equipment': 'Barbell',
    'primaryMuscle': 'Hamstrings',
    'primaryMuscles': ['Hamstrings', 'Glutes'],
    'secondaryMuscles': ['Erectors'],
    'stabilizers': ['Forearms'],
    'cnsScore': 9,
    'recoveryImpact': 5,
    'loggingMetric': 'weight_reps',
    'supportsWeightedBodyweight': false,
    'defaultRestSeconds': 240,
    'derived': true,
  },
  {
    'name': 'Lateral Raise',
    'aka': ['Side Raise'],
    'category': 'hypertrophy',
    'movementPattern': 'isolation',
    'modality': 'dumbbell',
    'equipment': 'Dumbbell',
    'primaryMuscle': 'Shoulders',
    'primaryMuscles': ['Side Delts'],
    'secondaryMuscles': [],
    'stabilizers': [],
    'cnsScore': 2,
    'recoveryImpact': 1,
    'loggingMetric': 'weight_reps',
    'supportsWeightedBodyweight': false,
    'defaultRestSeconds': 60,
    'derived': true,
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Clear whatever onCreate seeded so we measure the importer precisely.
    await db.delete(db.exerciseMuscles).go();
    await db.delete(db.exerciseAliases).go();
    await db.delete(db.exerciseCatalog).go();
  });

  tearDown(() async => db.close());

  test('imports exercises with muscles and aliases', () async {
    await ExerciseImporter.runFromJson(db, _sample);

    final catalog = await db.select(db.exerciseCatalog).get();
    expect(catalog, hasLength(2));

    final deadlift =
        catalog.firstWhere((e) => e.name == 'Conventional Deadlift');
    expect(deadlift.cnsScore, 9);
    expect(deadlift.modality, 'barbell');
    expect(deadlift.isReviewed, isFalse); // derived ⇒ unreviewed
    expect(deadlift.primaryMuscle, 'Hamstrings'); // coarse legacy column

    final muscles = await (db.select(db.exerciseMuscles)
          ..where((t) => t.exerciseId.equals(deadlift.id)))
        .get();
    expect(muscles.where((m) => m.role == 'primary'), hasLength(2));
    expect(muscles.where((m) => m.role == 'secondary'), hasLength(1));
    expect(muscles.where((m) => m.role == 'stabilizer'), hasLength(1));

    final aliases = await db.select(db.exerciseAliases).get();
    expect(aliases.map((a) => a.alias), containsAll(['Deads', 'Deadlift']));
  });

  test('is idempotent — re-running preserves ids and does not duplicate',
      () async {
    await ExerciseImporter.runFromJson(db, _sample);
    final firstId =
        (await db.select(db.exerciseCatalog).get()).map((e) => e.id).toList()
          ..sort();

    await ExerciseImporter.runFromJson(db, _sample);
    final after = await db.select(db.exerciseCatalog).get();
    final secondId = after.map((e) => e.id).toList()..sort();

    expect(after, hasLength(2), reason: 'no duplicate rows on re-import');
    expect(secondId, firstId, reason: 'row ids are preserved');

    final muscles = await db.select(db.exerciseMuscles).get();
    // 2 + 1 + 1 (deadlift) + 1 (lateral raise) = 5 — replaced, not appended.
    expect(muscles, hasLength(5));
  });

  test('alias search returns the parent exercise (canonical name shown)',
      () async {
    await ExerciseImporter.runFromJson(db, _sample);
    final repo = WorkoutsRepository(db, const SystemClock());

    final byAlias = await repo.watchExercises(query: 'Deads').first;
    expect(byAlias, hasLength(1));
    expect(byAlias.first.name, 'Conventional Deadlift');

    final bySideRaise = await repo.watchExercises(query: 'Side Raise').first;
    expect(bySideRaise.single.name, 'Lateral Raise');
  });

  test('the real generated catalog asset imports cleanly', () async {
    final json = File('assets/data/exercises.json').readAsStringSync();
    await ExerciseImporter.runFromJson(db, json);

    final catalog = await db.select(db.exerciseCatalog).get();
    expect(catalog.length, greaterThan(390),
        reason: 'full 398-exercise dataset should load');
    // Every row carries a derived CNS score and primary muscle.
    expect(catalog.every((e) => e.cnsScore >= 1 && e.cnsScore <= 10), isTrue);
    expect(catalog.every((e) => e.primaryMuscle.isNotEmpty), isTrue);
    // Granular muscle involvement was written for the catalog.
    final muscles = await db.select(db.exerciseMuscles).get();
    expect(muscles.length, greaterThan(catalog.length));

    final repo = WorkoutsRepository(db, const SystemClock());
    final deads = await repo.watchExercises(query: 'Deads').first;
    expect(deads.any((e) => e.name == 'Conventional Deadlift'), isTrue);
  });

  test('equipment variants of one movement share a movementFamily', () async {
    final json = File('assets/data/exercises.json').readAsStringSync();
    await ExerciseImporter.runFromJson(db, json);
    final catalog = await db.select(db.exerciseCatalog).get();

    ExerciseCatalogData byName(String n) =>
        catalog.firstWhere((e) => e.name == n);

    final inclineFamilies = {
      byName('Incline Barbell Bench').movementFamily,
      byName('Incline Dumbbell Press').movementFamily,
      byName('Machine Incline Press').movementFamily,
      byName('Swiss Bar Incline Press').movementFamily,
    };
    expect(inclineFamilies, hasLength(1),
        reason: 'all four incline presses collapse to one family');
    expect(inclineFamilies.single, isNotNull);

    // Flat bench is a different movement and must NOT merge with incline.
    expect(byName('Barbell Bench Press').movementFamily,
        isNot(inclineFamilies.single),
        reason: 'incline and flat press are distinct families');
  });
}
