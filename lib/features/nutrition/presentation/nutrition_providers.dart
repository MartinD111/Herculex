import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../data/nutrition_repository.dart';
import '../data/openfoodfacts_client.dart';
import '../domain/daily_totals.dart';
import '../domain/macro_targets.dart';
import '../domain/meal.dart';
import '../domain/carb_cycling.dart';
import '../domain/target_resolver.dart';
import '../data/carb_cycle_service.dart';
import '../data/wear_sync_service.dart';
import '../../analytics/presentation/analytics_providers.dart';


final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>((ref) {
  final c = OpenFoodFactsClient();
  ref.onDispose(c.dispose);
  return c;
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(openFoodFactsClientProvider),
    ref.watch(clockProvider),
  );
});

/// Currently-viewed date in the Nutrition tab. Always a date-only value
/// (midnight, no time component) so the [entriesForDateProvider] /
/// [dailyTotalsProvider] family keys stay stable as the user pages between
/// days. Initialized from the injectable clock.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final n = ref.watch(clockProvider).now();
  return DateTime(n.year, n.month, n.day);
});

final entriesForDateProvider =
    StreamProvider.autoDispose.family<List<FoodEntryData>, DateTime>((ref, date) {
  return ref.watch(nutritionRepositoryProvider).watchEntriesForDate(date);
});

final dailyTotalsProvider =
    StreamProvider.autoDispose.family<DailyTotals, DateTime>((ref, date) {
  return ref.watch(nutritionRepositoryProvider).watchDailyTotals(date);
});

/// Profile-derived baseline target (Mifflin-St Jeor). Used as the fallback
/// when no day-specific rule applies.
final baselineTargetsProvider = Provider<MacroTargets?>((ref) {
  final profile = ref.watch(profileProvider).asData?.value;
  if (profile == null) return null;
  return MacroTargets.fromProfile(profile);
});

final nutritionTargetsProvider =
    StreamProvider<List<NutritionTargetData>>((ref) {
  return ref.watch(nutritionRepositoryProvider).watchTargets();
});

final activeDietScheduleProvider =
    StreamProvider<DietScheduleData?>((ref) {
  return ref.watch(nutritionRepositoryProvider).watchActiveDietSchedule();
});

/// Effective target for the selected date (§19): day-specific rule resolution
/// over training/rest/weekday/date scopes, then automated diet-schedule
/// reduction, falling back to the profile baseline.
final effectiveTargetsProvider =
    FutureProvider.autoDispose.family<MacroTargets?, DateTime>((ref, date) async {
  final repo = ref.watch(nutritionRepositoryProvider);
  final rows = await ref.watch(nutritionTargetsProvider.future);
  final schedule = await ref.watch(activeDietScheduleProvider.future);
  final baseline = ref.watch(baselineTargetsProvider);
  final isTrainingDay = await repo.trainedOn(date);

  return TargetResolver.resolve(
    rules: [
      for (final r in rows)
        TargetRule(
          kcal: r.kcal,
          proteinG: r.proteinG,
          carbsG: r.carbsG,
          fatG: r.fatG,
          fiberG: r.fiberG,
          appliesTo: r.appliesTo,
        ),
    ],
    date: date,
    isTrainingDay: isTrainingDay,
    schedule: schedule == null
        ? null
        : DietScheduleRule(
            startDate: parseDateIso(schedule.startDateIso),
            reducePct: schedule.reducePct,
            intervalDays: schedule.intervalDays,
            active: schedule.active,
          ),
    fallback: baseline,
  );
});

final foodSearchProvider =
    StreamProvider.family<List<FoodData>, String?>((ref, query) {
  return ref.watch(nutritionRepositoryProvider).watchFoods(query: query);
});

final recipesProvider = StreamProvider<List<RecipeData>>((ref) {
  return ref.watch(nutritionRepositoryProvider).watchRecipes();
});

final recipeIngredientsProvider =
    StreamProvider.family<List<RecipeIngredientData>, int>((ref, recipeId) {
  return ref.watch(nutritionRepositoryProvider).watchIngredients(recipeId);
});

final recentFoodsProvider = FutureProvider<List<FoodData>>((ref) {
  return ref.watch(nutritionRepositoryProvider).recentFoods();
});

/// Group entries by meal for rendering meal sections.
final entriesByMealProvider = Provider.autoDispose
    .family<AsyncValue<Map<Meal, List<FoodEntryData>>>, DateTime>((ref, date) {
  final async = ref.watch(entriesForDateProvider(date));
  return async.whenData((entries) {
    final out = <Meal, List<FoodEntryData>>{
      for (final m in Meal.values) m: <FoodEntryData>[],
    };
    for (final e in entries) {
      final m = Meal.fromName(e.meal);
      out[m]!.add(e);
    }
    return out;
  });
});

/// Auto-generated carb-cycle levels (Mon→Sun) for the selected date's week,
/// derived from the training snapshot (§19).
final generatedCarbCycleProvider =
    FutureProvider.autoDispose.family<List<CarbLevel>, DateTime>((ref, date) async {
  final snapshot = await ref.watch(trainingSnapshotProvider.future);
  return CarbCycleService.planForWeek(snapshot: snapshot, weekStart: date);
});

final wearSyncServiceProvider = Provider<WearSyncService>((ref) {
  return WearSyncService();
});

final wearSyncControllerProvider = Provider<void>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  ref.listen<AsyncValue<DailyTotals>>(
    dailyTotalsProvider(today),
    (previous, next) {
      if (next.hasValue && next.value != null) {
        final totals = next.value!;
        ref.read(wearSyncServiceProvider).syncMacros(
          totals.kcal.round(),
          totals.proteinG.round(),
        );
      }
    },
    fireImmediately: true,
  );
});
