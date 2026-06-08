import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed_data.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseCatalog,
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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
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
        },
      );

  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(
        exerciseCatalog,
        kSeedExercises.map(
          (e) => ExerciseCatalogCompanion.insert(
            name: e.name,
            primaryMuscle: e.primaryMuscle,
            equipment: e.equipment,
            mechanics: e.mechanics,
            force: e.force,
            plane: e.plane,
            defaultRestSeconds: Value(e.defaultRestSeconds),
          ),
        ),
      );
    });
  }
}

QueryExecutor _open() => driftDatabase(name: 'herculex');
