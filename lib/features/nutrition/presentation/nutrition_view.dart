import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final totals = totalsAsync.asData?.value ?? DailyTotals.empty;
    final entriesByMeal = ref.watch(entriesByMealProvider(date));
    // Day-specific / diet-scheduled effective target (§19); baseline fallback.
    final targets = ref.watch(effectiveTargetsProvider(date)).asData?.value ??
        ref.watch(baselineTargetsProvider);

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
                totals: totals,
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
            if (totals.hasMicros)
              _MineralsRow(totals: totals, theme: theme),
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
          // DateUtils.addDaysToDate is DST-safe and returns a date-only value,
          // keeping the provider family key stable across day changes.
          onPressed: () => ref.read(selectedDateProvider.notifier).state =
              DateUtils.addDaysToDate(date, -1),
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
              ref.read(selectedDateProvider.notifier).state =
                  DateUtils.dateOnly(picked);
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
                  DateUtils.addDaysToDate(date, 1),
        ),
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'Targets & dieting',
          onPressed: () => context.push('/nutrition-targets'),
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
            onTap: display == null ? null : () => _showEntryDetail(context, theme, display),
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
    return _EntryDisplay(name: name, subtitle: subtitle, kcal: macros.kcal,
        sodiumMg: macros.sodiumMg, potassiumMg: macros.potassiumMg, cholesterolMg: macros.cholesterolMg);
  }

  void _showEntryDetail(BuildContext context, ThemeData theme, _EntryDisplay display) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final hasMicros = display.sodiumMg > 0 || display.potassiumMg > 0 || display.cholesterolMg > 0;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(display.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(display.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
              const SizedBox(height: 20),
              Text('${display.kcal.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (hasMicros) ...[
                const SizedBox(height: 16),
                Text('MINERALS', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                microRow('Sodium', display.sodiumMg, 'mg', theme),
                microRow('Potassium', display.potassiumMg, 'mg', theme),
                microRow('Cholesterol', display.cholesterolMg, 'mg', theme),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
  final double sodiumMg;
  final double potassiumMg;
  final double cholesterolMg;
  _EntryDisplay({
    required this.name,
    required this.subtitle,
    required this.kcal,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.cholesterolMg = 0,
  });
}

class _MineralsRow extends StatefulWidget {
  final DailyTotals totals;
  final ThemeData theme;
  const _MineralsRow({required this.totals, required this.theme});

  @override
  State<_MineralsRow> createState() => _MineralsRowState();
}

class _MineralsRowState extends State<_MineralsRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.totals;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text('MINERALS', style: widget.theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.secondary),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                microRow('Sodium', t.sodiumMg, 'mg', widget.theme),
                microRow('Potassium', t.potassiumMg, 'mg', widget.theme),
                microRow('Cholesterol', t.cholesterolMg, 'mg', widget.theme),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget microRow(String label, double value, String unit, ThemeData theme) {
  if (value <= 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
        Text('${value.toStringAsFixed(0)} $unit', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
