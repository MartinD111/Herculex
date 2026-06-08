import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'exercise_importer.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseCatalog,
    ExerciseMuscles,
    ExerciseAliases,
    WorkoutSessions,
    WorkoutExercises,
    SetEntries,
    Foods,
    Recipes,
    RecipeIngredients,
    FoodEntries,
    DailySummaries,
    FastingSessions,
    Programs,
    ProgramWeeks,
    ProgramDays,
    ProgramDayExercises,
    ScheduledWorkouts,
    ExternalEvents,
    HealthSamples,
    CycleLogs,
    CycleSettings,
    PendingSyncOps,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await ExerciseImporter.runFromAsset(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(foods);
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(foodEntries);
            await m.createTable(dailySummaries);
          }
          if (from < 3) {
            await m.createTable(fastingSessions);
          }
          if (from < 4) {
            await m.createTable(programs);
            await m.createTable(programWeeks);
            await m.createTable(programDays);
            await m.createTable(programDayExercises);
            await m.createTable(scheduledWorkouts);
            await m.createTable(externalEvents);
          }
          if (from < 5) {
            await m.createTable(healthSamples);
          }
          if (from < 6) {
            await m.createTable(cycleLogs);
            await m.createTable(cycleSettings);
          }
          if (from < 7) {
            await m.createTable(pendingSyncOps);
          }
          if (from < 8) {
            // Exercise Intelligence: enrich ExerciseCatalog + normalized tables.
            await m.addColumn(exerciseCatalog, exerciseCatalog.aka);
            await m.addColumn(exerciseCatalog, exerciseCatalog.category);
            await m.addColumn(exerciseCatalog, exerciseCatalog.movementPattern);
            await m.addColumn(
                exerciseCatalog, exerciseCatalog.movementPatternRaw);
            await m.addColumn(exerciseCatalog, exerciseCatalog.modality);
            await m.addColumn(exerciseCatalog, exerciseCatalog.cnsScore);
            await m.addColumn(exerciseCatalog, exerciseCatalog.recoveryImpact);
            await m.addColumn(exerciseCatalog, exerciseCatalog.loggingMetric);
            await m.addColumn(
                exerciseCatalog, exerciseCatalog.supportsWeightedBodyweight);
            await m.addColumn(exerciseCatalog, exerciseCatalog.attachments);
            await m.addColumn(exerciseCatalog, exerciseCatalog.isReviewed);
            await m.createTable(exerciseMuscles);
            await m.createTable(exerciseAliases);
            await ExerciseImporter.runFromAsset(this);
          }
        },
      );
}

QueryExecutor _open() => driftDatabase(name: 'herculex');
