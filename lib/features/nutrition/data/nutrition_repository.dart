import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../data/local/database.dart';
import '../domain/daily_totals.dart';
import '../domain/meal.dart';
import 'openfoodfacts_client.dart';
import 'remote_food.dart';

class NutritionRepository {
  final AppDatabase _db;
  final OpenFoodFactsClient _off;
  final Clock _clock;

  NutritionRepository(this._db, this._off, this._clock);

  // ── Foods ──────────────────────────────────────────────────────────────

  Stream<List<FoodData>> watchFoods({String? query}) {
    final q = _db.select(_db.foods)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      q.where((t) => t.name.like(like) | t.brand.like(like));
    }
    return q.watch();
  }

  /// Local-first search. If [includeRemote] and we have fewer than 3 local
  /// matches, hit OpenFoodFacts to backfill. OFF hits are cached into [foods].
  Future<List<FoodData>> searchFoods(String query,
      {bool includeRemote = false}) async {
    final local = await (_db.select(_db.foods)
          ..where((t) => t.name.like('%$query%') | t.brand.like('%$query%'))
          ..limit(20))
        .get();
    if (!includeRemote || local.length >= 3) return local;

    final remote = await _off.search(query);
    if (remote.isEmpty) return local;

    // Cache remote results and return the union (local first).
    final cached = <FoodData>[];
    for (final r in remote) {
      final existing = await _findByBarcode(r.barcode);
      if (existing != null) {
        cached.add(existing);
      } else {
        final id = await _insertRemote(r);
        final row = await (_db.select(_db.foods)..where((t) => t.id.equals(id)))
            .getSingle();
        cached.add(row);
      }
    }
    final ids = local.map((f) => f.id).toSet();
    return [...local, ...cached.where((f) => !ids.contains(f.id))];
  }

  /// Local hit → return. OFF hit → cache then return. Miss → null.
  Future<FoodData?> lookupBarcode(String barcode) async {
    final cached = await _findByBarcode(barcode);
    if (cached != null) return cached;

    final remote = await _off.lookupBarcode(barcode);
    if (remote == null) return null;

    final id = await _insertRemote(remote);
    return (_db.select(_db.foods)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<FoodData?> _findByBarcode(String? barcode) async {
    if (barcode == null || barcode.isEmpty) return null;
    return (_db.select(_db.foods)..where((t) => t.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  Future<int> _insertRemote(RemoteFood r) => _db.into(_db.foods).insert(
        FoodsCompanion.insert(
          name: r.name,
          brand: Value(r.brand),
          barcode: Value(r.barcode),
          kcalPer100g: r.kcalPer100g,
          proteinPer100g: Value(r.proteinPer100g),
          carbsPer100g: Value(r.carbsPer100g),
          fatPer100g: Value(r.fatPer100g),
          fiberPer100g: Value(r.fiberPer100g),
          servingGrams: Value(r.servingGrams),
          servingLabel: Value(r.servingLabel),
          source: const Value('openfoodfacts'),
          imageUrl: Value(r.imageUrl),
        ),
      );

  Future<FoodData> createCustomFood({
    required String name,
    String? brand,
    required double kcalPer100g,
    double proteinPer100g = 0,
    double carbsPer100g = 0,
    double fatPer100g = 0,
    double? servingGrams,
    String? servingLabel,
    double? sodiumMgPer100g,
    double? potassiumMgPer100g,
    double? cholesterolMgPer100g,
  }) async {
    final id = await _db.into(_db.foods).insert(
          FoodsCompanion.insert(
            name: name,
            brand: Value(brand),
            kcalPer100g: kcalPer100g,
            proteinPer100g: Value(proteinPer100g),
            carbsPer100g: Value(carbsPer100g),
            fatPer100g: Value(fatPer100g),
            servingGrams: Value(servingGrams),
            servingLabel: Value(servingLabel),
            source: const Value('local'),
            isCustom: const Value(true),
            sodiumMgPer100g: Value(sodiumMgPer100g),
            potassiumMgPer100g: Value(potassiumMgPer100g),
            cholesterolMgPer100g: Value(cholesterolMgPer100g),
          ),
        );
    return (_db.select(_db.foods)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> deleteFood(int id) async {
    await (_db.delete(_db.foods)..where((t) => t.id.equals(id))).go();
  }

  // ── Recipes ────────────────────────────────────────────────────────────

  Stream<List<RecipeData>> watchRecipes() {
    return (_db.select(_db.recipes)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> createRecipe({required String name, int servings = 1, String? notes}) {
    return _db.into(_db.recipes).insert(
          RecipesCompanion.insert(
            name: name,
            servings: Value(servings),
            notes: Value(notes),
          ),
        );
  }

  Future<void> deleteRecipe(int id) async {
    await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<RecipeIngredientData>> watchIngredients(int recipeId) {
    return (_db.select(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .watch();
  }

  Future<void> addIngredient({
    required int recipeId,
    required int foodId,
    required double grams,
  }) async {
    await _db.into(_db.recipeIngredients).insert(
          RecipeIngredientsCompanion.insert(
            recipeId: recipeId,
            foodId: foodId,
            grams: grams,
          ),
        );
  }

  Future<void> removeIngredient(int id) async {
    await (_db.delete(_db.recipeIngredients)..where((t) => t.id.equals(id))).go();
  }

  /// Macros per serving for a recipe.
  Future<DailyTotals> recipeMacrosPerServing(int recipeId) async {
    final recipe = await (_db.select(_db.recipes)..where((t) => t.id.equals(recipeId)))
        .getSingleOrNull();
    if (recipe == null) return DailyTotals.empty;

    final ings = await (_db.select(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .get();
    if (ings.isEmpty) return DailyTotals.empty;

    final foodIds = ings.map((i) => i.foodId).toSet().toList();
    final foods = await (_db.select(_db.foods)..where((t) => t.id.isIn(foodIds))).get();
    final byId = {for (final f in foods) f.id: f};

    var totals = DailyTotals.empty;
    for (final ing in ings) {
      final food = byId[ing.foodId];
      if (food == null) continue;
      final factor = ing.grams / 100.0;
      totals = totals.plus(
        kcal: food.kcalPer100g * factor,
        proteinG: food.proteinPer100g * factor,
        carbsG: food.carbsPer100g * factor,
        fatG: food.fatPer100g * factor,
        fiberG: (food.fiberPer100g ?? 0) * factor,
        sodiumMg: (food.sodiumMgPer100g ?? 0) * factor,
        potassiumMg: (food.potassiumMgPer100g ?? 0) * factor,
        cholesterolMg: (food.cholesterolMgPer100g ?? 0) * factor,
      );
    }

    final servings = recipe.servings == 0 ? 1 : recipe.servings;
    return DailyTotals(
      kcal: totals.kcal / servings,
      proteinG: totals.proteinG / servings,
      carbsG: totals.carbsG / servings,
      fatG: totals.fatG / servings,
      fiberG: totals.fiberG / servings,
      sodiumMg: totals.sodiumMg / servings,
      potassiumMg: totals.potassiumMg / servings,
      cholesterolMg: totals.cholesterolMg / servings,
    );
  }

  // ── Entries (the daily diary) ──────────────────────────────────────────

  Stream<List<FoodEntryData>> watchEntriesForDate(DateTime date) {
    final iso = dateIso(date);
    return (_db.select(_db.foodEntries)
          ..where((t) => t.dateIso.equals(iso))
          ..orderBy([(t) => OrderingTerm(expression: t.loggedAt)]))
        .watch();
  }

  Future<void> logFood({
    required DateTime date,
    required Meal meal,
    required int foodId,
    required double grams,
  }) async {
    await _db.into(_db.foodEntries).insert(
          FoodEntriesCompanion.insert(
            dateIso: dateIso(date),
            meal: meal.name,
            foodId: Value(foodId),
            servings: const Value(1),
            gramsOverride: Value(grams),
            // §22 fix: stamp loggedAt from the local Clock so it agrees with
            // the local-derived dateIso. SQLite's default CURRENT_TIMESTAMP is
            // UTC, which drifts entries onto the wrong calendar day for users
            // behind UTC and corrupts recentFoods' loggedAt cutoff.
            loggedAt: Value(_clock.now()),
          ),
        );
  }

  Future<void> logRecipe({
    required DateTime date,
    required Meal meal,
    required int recipeId,
    required double servings,
  }) async {
    await _db.into(_db.foodEntries).insert(
          FoodEntriesCompanion.insert(
            dateIso: dateIso(date),
            meal: meal.name,
            recipeId: Value(recipeId),
            servings: Value(servings),
            loggedAt: Value(_clock.now()),
          ),
        );
  }

  Future<void> deleteEntry(int id) async {
    await (_db.delete(_db.foodEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Resolves an entry's macro contribution, handling both food and recipe.
  Future<DailyTotals> macrosForEntry(FoodEntryData entry) async {
    if (entry.foodId != null) {
      final food = await (_db.select(_db.foods)..where((t) => t.id.equals(entry.foodId!)))
          .getSingleOrNull();
      if (food == null) return DailyTotals.empty;
      final grams = entry.gramsOverride ?? food.servingGrams ?? 100;
      final f = grams / 100.0;
      return DailyTotals(
        kcal: food.kcalPer100g * f,
        proteinG: food.proteinPer100g * f,
        carbsG: food.carbsPer100g * f,
        fatG: food.fatPer100g * f,
        fiberG: (food.fiberPer100g ?? 0) * f,
        sodiumMg: (food.sodiumMgPer100g ?? 0) * f,
        potassiumMg: (food.potassiumMgPer100g ?? 0) * f,
        cholesterolMg: (food.cholesterolMgPer100g ?? 0) * f,
      );
    }
    if (entry.recipeId != null) {
      final per = await recipeMacrosPerServing(entry.recipeId!);
      return DailyTotals(
        kcal: per.kcal * entry.servings,
        proteinG: per.proteinG * entry.servings,
        carbsG: per.carbsG * entry.servings,
        fatG: per.fatG * entry.servings,
        fiberG: per.fiberG * entry.servings,
        sodiumMg: per.sodiumMg * entry.servings,
        potassiumMg: per.potassiumMg * entry.servings,
        cholesterolMg: per.cholesterolMg * entry.servings,
      );
    }
    return DailyTotals.empty;
  }

  /// Stream of pre-computed totals for a date. Re-emits when entries change.
  Stream<DailyTotals> watchDailyTotals(DateTime date) async* {
    await for (final entries in watchEntriesForDate(date)) {
      var totals = DailyTotals.empty;
      for (final e in entries) {
        final m = await macrosForEntry(e);
        totals = totals.plus(
          kcal: m.kcal,
          proteinG: m.proteinG,
          carbsG: m.carbsG,
          fatG: m.fatG,
          fiberG: m.fiberG,
          sodiumMg: m.sodiumMg,
          potassiumMg: m.potassiumMg,
          cholesterolMg: m.cholesterolMg,
        );
      }
      yield totals;
    }
  }

  // ── Nutrition targets, diet schedules, carb plans (v12, §19) ────────────

  Stream<List<NutritionTargetData>> watchTargets() {
    return _db.select(_db.nutritionTargets).watch();
  }

  /// Upserts the target for a scope key (one row per [appliesTo]). Conflict
  /// target is the [appliesTo] unique key, not the primary key, so re-saving
  /// the same scope updates rather than throwing.
  Future<void> upsertTarget({
    required String label,
    required String appliesTo,
    required int kcal,
    required int proteinG,
    required int carbsG,
    required int fatG,
    int? fiberG,
  }) async {
    await _db.into(_db.nutritionTargets).insert(
          NutritionTargetsCompanion.insert(
            label: label,
            appliesTo: Value(appliesTo),
            kcal: kcal,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: Value(fiberG),
          ),
          onConflict: DoUpdate(
            (old) => NutritionTargetsCompanion.custom(
              label: Constant(label),
              kcal: Constant(kcal),
              proteinG: Constant(proteinG),
              carbsG: Constant(carbsG),
              fatG: Constant(fatG),
              fiberG: fiberG == null ? const Constant(null) : Constant(fiberG),
            ),
            target: [_db.nutritionTargets.appliesTo],
          ),
        );
  }

  Future<void> deleteTarget(int id) async {
    await (_db.delete(_db.nutritionTargets)..where((t) => t.id.equals(id))).go();
  }

  Stream<DietScheduleData?> watchActiveDietSchedule() {
    return (_db.select(_db.dietSchedules)
          ..where((t) => t.active.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.startDateIso, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<int> startDietSchedule({
    required DateTime startDate,
    required double reducePct,
    required int intervalDays,
  }) async {
    return _db.transaction(() async {
      // Only one active schedule at a time.
      await (_db.update(_db.dietSchedules)..where((t) => t.active.equals(true)))
          .write(const DietSchedulesCompanion(active: Value(false)));
      return _db.into(_db.dietSchedules).insert(
            DietSchedulesCompanion.insert(
              startDateIso: dateIso(startDate),
              reducePct: reducePct,
              intervalDays: intervalDays,
            ),
          );
    });
  }

  Future<void> stopDietSchedules() async {
    await (_db.update(_db.dietSchedules)..where((t) => t.active.equals(true)))
        .write(const DietSchedulesCompanion(active: Value(false)));
  }

  Future<void> saveCarbCyclePlan({
    required DateTime weekStart,
    required String dayLevelsJson,
    bool auto = true,
  }) async {
    await _db.into(_db.carbCyclePlans).insert(
          CarbCyclePlansCompanion.insert(
            weekStartIso: dateIso(weekStart),
            dayLevelsJson: dayLevelsJson,
            auto: Value(auto),
          ),
          onConflict: DoUpdate(
            (old) => CarbCyclePlansCompanion.custom(
              dayLevelsJson: Constant(dayLevelsJson),
              auto: Constant(auto),
            ),
            target: [_db.carbCyclePlans.weekStartIso],
          ),
        );
  }

  Future<CarbCyclePlanData?> carbCyclePlanForWeek(DateTime weekStart) {
    return (_db.select(_db.carbCyclePlans)
          ..where((t) => t.weekStartIso.equals(dateIso(weekStart))))
        .getSingleOrNull();
  }

  /// Whether the user trained on [date] (any completed session that day) —
  /// drives training-day vs rest-day target selection.
  Future<bool> trainedOn(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) =>
              t.endedAt.isNotNull() &
              t.startedAt.isBiggerOrEqualValue(from) &
              t.startedAt.isSmallerThanValue(to))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Top N foods most frequently logged in the last 30 days.
  Future<List<FoodData>> recentFoods({int limit = 20}) async {
    final cutoff = _clock.now().subtract(const Duration(days: 30));
    final entries = await (_db.select(_db.foodEntries)
          ..where((t) =>
              t.foodId.isNotNull() & t.loggedAt.isBiggerOrEqualValue(cutoff)))
        .get();

    final counts = <int, int>{};
    for (final e in entries) {
      final id = e.foodId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return const [];

    final topIds = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = topIds.take(limit).map((e) => e.key).toList();
    final foods = await (_db.select(_db.foods)..where((t) => t.id.isIn(ids))).get();
    // Preserve frequency order.
    final byId = {for (final f in foods) f.id: f};
    return [for (final id in ids) byId[id]].whereType<FoodData>().toList();
  }
}
