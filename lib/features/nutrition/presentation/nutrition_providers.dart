import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../data/nutrition_repository.dart';
import '../data/openfoodfacts_client.dart';
import '../domain/daily_totals.dart';
import '../domain/macro_targets.dart';
import '../domain/meal.dart';
import '../data/wear_sync_service.dart';


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

/// Currently-viewed date in the Nutrition tab + dashboard summary.
final selectedDateProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

final entriesForDateProvider =
    StreamProvider.family<List<FoodEntryData>, DateTime>((ref, date) {
  return ref.watch(nutritionRepositoryProvider).watchEntriesForDate(date);
});

final dailyTotalsProvider =
    StreamProvider.family<DailyTotals, DateTime>((ref, date) {
  return ref.watch(nutritionRepositoryProvider).watchDailyTotals(date);
});

final macroTargetsProvider = Provider<MacroTargets?>((ref) {
  final profile = ref.watch(profileProvider).asData?.value;
  if (profile == null) return null;
  return MacroTargets.fromProfile(profile);
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
final entriesByMealProvider =
    Provider.family<AsyncValue<Map<Meal, List<FoodEntryData>>>, DateTime>(
        (ref, date) {
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
