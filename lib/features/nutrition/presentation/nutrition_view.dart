import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../domain/daily_totals.dart';
import '../domain/meal.dart';
import 'food_picker_sheet.dart';
import 'macro_rings.dart';
import 'nutrition_providers.dart';

class NutritionView extends ConsumerWidget {
  const NutritionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = ref.watch(selectedDateProvider);
    final totalsAsync = ref.watch(dailyTotalsProvider(date));
    final entriesByMeal = ref.watch(entriesByMealProvider(date));
    final targets = ref.watch(macroTargetsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            _buildDateHeader(context, ref, date, theme),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: MacroRings(
                totals: totalsAsync.asData?.value ?? DailyTotals.empty,
                targets: targets,
              ),
            ),
            if (targets == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  'Add your weight, height, and age in profile to compute macro targets.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ),
            const SizedBox(height: 24),
            entriesByMeal.when(
              data: (byMeal) => Column(
                children: [
                  for (final m in Meal.values)
                    _MealSection(
                      meal: m,
                      entries: byMeal[m]!,
                      date: date,
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, WidgetRef ref, DateTime date, ThemeData theme) {
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final label = isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(selectedDateProvider.notifier).state =
              date.subtract(const Duration(days: 1)),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: today.add(const Duration(days: 30)),
            );
            if (picked != null) {
              ref.read(selectedDateProvider.notifier).state = picked;
            }
          },
          child: Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday
              ? null
              : () => ref.read(selectedDateProvider.notifier).state =
                  date.add(const Duration(days: 1)),
        ),
      ],
    );
  }
}

class _MealSection extends ConsumerWidget {
  final Meal meal;
  final List<FoodEntryData> entries;
  final DateTime date;

  const _MealSection({required this.meal, required this.entries, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.label,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: () => FoodPickerSheet.show(context, date: date, meal: meal),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              child: Text(
                'Nothing logged.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
              ),
            )
          else
            ...entries.map((e) => _EntryTile(entry: e)),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final FoodEntryData entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.watch(nutritionRepositoryProvider);

    return FutureBuilder<_EntryDisplay>(
      future: _resolve(ref),
      builder: (context, snap) {
        final display = snap.data;
        return Dismissible(
          key: ValueKey('entry_${entry.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.redAccent.withValues(alpha: 0.85),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => repo.deleteEntry(entry.id),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            dense: true,
            title: Text(display?.name ?? 'Loading…', style: theme.textTheme.bodyMedium),
            subtitle: Text(
              display?.subtitle ?? '',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
            trailing: Text(
              display == null ? '' : '${display.kcal.toStringAsFixed(0)} kcal',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Future<_EntryDisplay> _resolve(WidgetRef ref) async {
    final repo = ref.read(nutritionRepositoryProvider);
    final macros = await repo.macrosForEntry(entry);
    final name = await _resolveName(ref);
    final subtitle = entry.foodId != null
        ? '${(entry.gramsOverride ?? 0).toStringAsFixed(0)} g'
        : '${entry.servings.toStringAsFixed(entry.servings.truncateToDouble() == entry.servings ? 0 : 1)} serv';
    return _EntryDisplay(name: name, subtitle: subtitle, kcal: macros.kcal);
  }

  Future<String> _resolveName(WidgetRef ref) async {
    if (entry.foodId != null) {
      final list = await ref.read(foodSearchProvider(null).future);
      return list.firstWhere(
        (f) => f.id == entry.foodId,
        orElse: () => _placeholderFood(),
      ).name;
    }
    if (entry.recipeId != null) {
      final list = await ref.read(recipesProvider.future);
      return list.firstWhere(
        (r) => r.id == entry.recipeId,
        orElse: () => _placeholderRecipe(),
      ).name;
    }
    return '—';
  }

  FoodData _placeholderFood() => FoodData(
        id: 0,
        name: '—',
        kcalPer100g: 0,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 0,
        source: 'local',
        isCustom: false,
        createdAt: DateTime.now(),
      );

  RecipeData _placeholderRecipe() =>
      RecipeData(id: 0, name: '—', servings: 1, createdAt: DateTime.now());
}

class _EntryDisplay {
  final String name;
  final String subtitle;
  final double kcal;
  _EntryDisplay({required this.name, required this.subtitle, required this.kcal});
}
