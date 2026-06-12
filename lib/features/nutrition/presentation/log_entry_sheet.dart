import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../widgets/premium_button.dart';
import '../domain/meal.dart';
import 'nutrition_providers.dart';

/// Final step before logging: choose grams (food) or servings (recipe), pick meal.
class LogEntrySheet extends ConsumerStatefulWidget {
  final FoodData? food;
  final RecipeData? recipe;
  final DateTime date;
  final Meal initialMeal;

  const LogEntrySheet._({
    this.food,
    this.recipe,
    required this.date,
    required this.initialMeal,
  });

  static Future<bool?> forFood(
    BuildContext context, {
    required FoodData food,
    required DateTime date,
    required Meal initialMeal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogEntrySheet._(food: food, date: date, initialMeal: initialMeal),
      ),
    );
  }

  static Future<bool?> forRecipe(
    BuildContext context, {
    required RecipeData recipe,
    required DateTime date,
    required Meal initialMeal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogEntrySheet._(recipe: recipe, date: date, initialMeal: initialMeal),
      ),
    );
  }

  @override
  ConsumerState<LogEntrySheet> createState() => _LogEntrySheetState();
}

class _LogEntrySheetState extends ConsumerState<LogEntrySheet> {
  late Meal _meal = widget.initialMeal;
  late final TextEditingController _quantity = TextEditingController(
    text: widget.food != null
        ? (widget.food!.servingGrams ?? 100).toStringAsFixed(0)
        : '1',
  );
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_quantity.text.trim());
    if (value == null || value <= 0) return;
    setState(() => _saving = true);
    final repo = ref.read(nutritionRepositoryProvider);
    if (widget.food != null) {
      await repo.logFood(date: widget.date, meal: _meal, foodId: widget.food!.id, grams: value);
    } else if (widget.recipe != null) {
      await repo.logRecipe(date: widget.date, meal: _meal, recipeId: widget.recipe!.id, servings: value);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFood = widget.food != null;
    final title = widget.food?.name ?? widget.recipe?.name ?? '';
    final subtitle = isFood
        ? '${widget.food!.kcalPer100g.toStringAsFixed(0)} kcal / 100 g'
        : '${widget.recipe!.servings} servings per recipe';
    final unit = isFood ? 'grams' : 'servings';

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
          const SizedBox(height: 24),
          Text(
            unit.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: theme.textTheme.displayMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'MEAL',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Meal.values)
                _MealChip(
                  label: m.label,
                  selected: _meal == m,
                  onTap: () => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: 28),
          PremiumButton(
            text: _saving ? 'Saving…' : 'Log',
            onTap: _saving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MealChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
