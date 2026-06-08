import 'package:drift/drift.dart';

/// Canonical exercise library. Most rows are seeded; user-created rows have
/// [isCustom] = true.
@DataClassName('ExerciseCatalogData')
class ExerciseCatalog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  // Legacy coarse muscle group (Chest|Back|Shoulders|Quads|…). Kept for
  // back-compat; granular involvement lives in [ExerciseMuscles].
  TextColumn get primaryMuscle => text()();
  TextColumn get equipment => text()();
  // compound | isolation
  TextColumn get mechanics => text()();
  // push | pull | static
  TextColumn get force => text()();
  // horizontal | vertical | axial | none
  TextColumn get plane => text()();
  IntColumn get defaultRestSeconds => integer().withDefault(const Constant(120))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  // ── Exercise Intelligence (v8) ──
  /// Denormalized alias blob for quick search; canonical aliases live in
  /// [ExerciseAliases]. Display always uses [name].
  TextColumn get aka => text().nullable()();
  // strength | hypertrophy | powerlifting | calisthenics | crossfit | cardio | mobility
  TextColumn get category => text().withDefault(const Constant('strength'))();
  // Coarse: squat | hinge | horizontal_push | vertical_push | horizontal_pull |
  // vertical_pull | lunge | carry | core | isolation | other
  TextColumn get movementPattern => text().nullable()();
  /// Original granular pattern text from the source dataset (fidelity).
  TextColumn get movementPatternRaw => text().nullable()();
  // barbell | dumbbell | machine_plate | machine_selectorized | cable | smith |
  // kettlebell | band | bodyweight | other
  TextColumn get modality => text().withDefault(const Constant('barbell'))();
  /// CNS fatigue cost, 1–10. Drives recovery + max-effort logic.
  IntColumn get cnsScore => integer().withDefault(const Constant(3))();
  /// Systemic recovery demand, 1–5.
  IntColumn get recoveryImpact => integer().withDefault(const Constant(3))();
  // weight_reps | reps | time | distance | time_distance | weight_time
  TextColumn get loggingMetric =>
      text().withDefault(const Constant('weight_reps'))();
  /// Enables the "+ added weight" field & bodyweight-base calculations.
  BoolColumn get supportsWeightedBodyweight =>
      boolean().withDefault(const Constant(false))();
  /// JSON list of attachment labels, e.g. ["rope","v-bar"]. Null = none.
  TextColumn get attachments => text().nullable()();
  /// False = attributes were machine-derived and not yet human-reviewed.
  BoolColumn get isReviewed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, equipment},
      ];
}

/// Normalized muscle involvement — the recovery engine's primary input.
@DataClassName('ExerciseMuscleData')
class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(ExerciseCatalog, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  // primary | secondary | stabilizer
  TextColumn get role => text()();
  RealColumn get contribution => real().withDefault(const Constant(1.0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {exerciseId, muscle, role},
      ];
}

/// Search aliases. Searching any alias returns the parent exercise; the parent's
/// [ExerciseCatalog.name] remains the only displayed name.
@DataClassName('ExerciseAliasData')
class ExerciseAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(ExerciseCatalog, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text()();
}

@DataClassName('WorkoutSessionData')
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  // Overall session RPE 1-10 (optional)
  IntColumn get sessionRpe => integer().nullable()();
}

@DataClassName('WorkoutExerciseData')
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(ExerciseCatalog, #id, onDelete: KeyAction.restrict)();
  IntColumn get orderIndex => integer()();
  // Same group number across rows ⇒ superset. Null = standalone.
  IntColumn get supersetGroup => integer().nullable()();
  IntColumn get targetRestSeconds => integer().nullable()();
}

@DataClassName('SetEntryData')
class SetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer()
      .references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  // RPE 1-10 (half-points allowed → stored × 10 to keep int math simple)
  IntColumn get rpeX10 => integer().nullable()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// ── Nutrition ──────────────────────────────────────────────────────────────

/// All nutrient values are per-100g (or per-100ml for liquids); convert via
/// [servingGrams] when displaying a serving-sized macro.
@DataClassName('FoodData')
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().nullable()();
  RealColumn get kcalPer100g => real()();
  RealColumn get proteinPer100g => real().withDefault(const Constant(0))();
  RealColumn get carbsPer100g => real().withDefault(const Constant(0))();
  RealColumn get fatPer100g => real().withDefault(const Constant(0))();
  RealColumn get fiberPer100g => real().nullable()();
  RealColumn get servingGrams => real().nullable()();
  TextColumn get servingLabel => text().nullable()(); // e.g. "1 cup", "1 slice"
  TextColumn get source => text().withDefault(const Constant('local'))(); // local | openfoodfacts
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('RecipeData')
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get servings => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('RecipeIngredientData')
class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId =>
      integer().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.restrict)();
  RealColumn get grams => real()();
}

/// One row per logged food/recipe per meal per day.
/// Exactly one of [foodId] / [recipeId] is populated.
@DataClassName('FoodEntryData')
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Stored as yyyy-mm-dd to keep date math timezone-stable in queries.
  TextColumn get dateIso => text()();
  TextColumn get meal => text()(); // breakfast | lunch | dinner | snack
  IntColumn get foodId =>
      integer().nullable().references(Foods, #id, onDelete: KeyAction.restrict)();
  IntColumn get recipeId =>
      integer().nullable().references(Recipes, #id, onDelete: KeyAction.restrict)();
  /// Servings consumed when logging a recipe; ignored for raw foods.
  RealColumn get servings => real().withDefault(const Constant(1))();
  /// Grams override for raw foods; ignored for recipes.
  RealColumn get gramsOverride => real().nullable()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DailySummaryData')
class DailySummaries extends Table {
  TextColumn get dateIso => text()();
  IntColumn get waterMl => integer().withDefault(const Constant(0))();
  RealColumn get weighInKg => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {dateIso};
}

@DataClassName('FastingSessionData')
class FastingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get targetSeconds => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

@DataClassName('ProgramData')
class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get weeks => integer().withDefault(const Constant(4))();
  TextColumn get type => text().withDefault(const Constant('block'))();
  TextColumn get progressionStrategy => text().withDefault(const Constant('volume'))();
  BoolColumn get createdByUser => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('ProgramWeekData')
class ProgramWeeks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIndex => integer()();
  RealColumn get adjustmentFactor => real().withDefault(const Constant(1.0))();
}

@DataClassName('ProgramDayData')
class ProgramDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programWeekId => integer().references(ProgramWeeks, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayOfWeek => integer()();
  TextColumn get name => text()();
}

@DataClassName('ProgramDayExerciseData')
class ProgramDayExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programDayId => integer().references(ProgramDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(ExerciseCatalog, #id, onDelete: KeyAction.restrict)();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetRepsMin => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();
  IntColumn get targetRpe => integer().nullable()();
  IntColumn get orderIndex => integer()();
}

@DataClassName('ScheduledWorkoutData')
class ScheduledWorkouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateIso => text()();
  IntColumn get programDayId => integer().references(ProgramDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get completedSessionId => integer().nullable().references(WorkoutSessions, #id, onDelete: KeyAction.setNull)();
  TextColumn get status => text().withDefault(const Constant('planned'))();
}

@DataClassName('ExternalEventData')
class ExternalEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateFromIso => text()();
  TextColumn get dateToIso => text()();
  TextColumn get type => text()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('HealthSampleData')
class HealthSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateIso => text()();
  TextColumn get kind => text()(); // steps | sleep_hours | active_kcal | resting_hr
  RealColumn get value => real()();
}

@DataClassName('CycleLogData')
class CycleLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateIso => text()();
  TextColumn get phase => text()(); // menstrual | follicular | ovulatory | luteal
  IntColumn get intensity => integer().withDefault(const Constant(3))();
  BoolColumn get manualOverride => boolean().withDefault(const Constant(false))();
}

@DataClassName('CycleSettingData')
class CycleSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get avgCycleDays => integer().withDefault(const Constant(28))();
  IntColumn get avgPeriodDays => integer().withDefault(const Constant(5))();
  DateTimeColumn get lastPeriodStart => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingSyncOpData')
class PendingSyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // profile | program | recipe | food | exercise
  TextColumn get entityId => text()();   // local unique identifier (UUID)
  TextColumn get operation => text()();  // upsert | delete
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}




