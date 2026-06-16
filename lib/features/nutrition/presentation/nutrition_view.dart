import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../data/nutrition_repository.dart';
import '../domain/daily_totals.dart';
import '../domain/meal.dart';
import 'food_picker_sheet.dart';
import 'macro_rings.dart';
import 'nutrition_providers.dart';

class NutritionView extends ConsumerStatefulWidget {
  const NutritionView({super.key});

  @override
  ConsumerState<NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends ConsumerState<NutritionView> {
  // Large virtual page space; page 5000 == today.
  static const int _kCenter = 5000;
  late final PageController _pageCtrl;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _kCenter);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  DateTime _pageToDate(int page) {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.addDaysToDate(today, page - _kCenter);
  }

  int _dateToPage(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    return _kCenter + date.difference(today).inDays;
  }

  void _onPageChanged(int page) {
    if (_settling) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final candidate = _pageToDate(page);
    if (candidate.isAfter(today)) {
      // Snap back — can't go to future
      _settling = true;
      _pageCtrl
          .animateToPage(
            _dateToPage(today),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .then((_) => _settling = false);
      return;
    }
    ref.read(selectedDateProvider.notifier).state = candidate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = ref.watch(selectedDateProvider);

    // If date was changed externally (date picker), sync the page controller.
    final targetPage = _dateToPage(date);
    if (_pageCtrl.hasClients &&
        _pageCtrl.page?.round() != targetPage &&
        !_settling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageCtrl.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: _buildDateHeader(context, date, theme),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, page) {
                  final pageDate = _pageToDate(page);
                  return _DayPage(date: pageDate);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date, ThemeData theme) {
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final label = isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final prev = DateUtils.addDaysToDate(date, -1);
            ref.read(selectedDateProvider.notifier).state = prev;
          },
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
              : () {
                  final next = DateUtils.addDaysToDate(date, 1);
                  ref.read(selectedDateProvider.notifier).state = next;
                },
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

// ── Per-day page rendered inside the PageView ────────────────────────────────

class _DayPage extends ConsumerWidget {
  final DateTime date;
  const _DayPage({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totalsAsync = ref.watch(dailyTotalsProvider(date));
    final totals = totalsAsync.asData?.value ?? DailyTotals.empty;
    final entriesByMeal = ref.watch(entriesByMealProvider(date));
    final targets = ref.watch(effectiveTargetsProvider(date)).asData?.value ??
        ref.watch(baselineTargetsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MacroRings(totals: totals, targets: targets),
        ),
        if (targets == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text(
              'Add your weight, height, and age in profile to compute macro targets.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
          ),
        if (totals.hasMicros) _MineralsRow(totals: totals, theme: theme),
        const SizedBox(height: 24),
        entriesByMeal.when(
          data: (byMeal) => Column(
            children: [
              for (final meal in Meal.values) ...[
                _MealAccordion(
                  meal: meal,
                  entries: byMeal[meal]!,
                  date: date,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

/// Expandable meal accordion. Header shows macro grams; tapping the macro row
/// toggles to % of that meal's total kcal. The "+ Add" button lives at the
/// bottom of the expanded body.
class _MealAccordion extends StatefulWidget {
  final Meal meal;
  final List<FoodEntryData> entries;
  final DateTime date;

  const _MealAccordion({
    required this.meal,
    required this.entries,
    required this.date,
  });

  @override
  State<_MealAccordion> createState() => _MealAccordionState();
}

class _MealAccordionState extends State<_MealAccordion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _showPercent = false;

  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  /// Compute per-meal macro totals synchronously from entry metadata stored
  /// on FoodEntryData. Full precision requires async repo calls; we approximate
  /// here using the cached kcal-equivalent fields when available, but the
  /// accurate path is the async _EntryTile which resolves per-food macros.
  /// For the header summary we use a FutureBuilder per accordion.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Text(
                    widget.meal.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.entries.length} item${widget.entries.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary),
                  ),
                  const Spacer(),
                  // Macro summary — tapping toggles g ↔ %
                  if (widget.entries.isNotEmpty)
                    _MealMacroSummary(
                      entries: widget.entries,
                      showPercent: _showPercent,
                      onToggle: () =>
                          setState(() => _showPercent = !_showPercent),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.expand_more,
                        size: 20, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ),
          // ── Body (animated) ─────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                if (widget.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Nothing logged.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary),
                    ),
                  )
                else
                  for (final e in widget.entries) _EntryTile(entry: e),
                // ── + Add button at bottom ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => FoodPickerSheet.show(
                        context,
                        date: widget.date,
                        meal: widget.meal,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add food'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves per-meal macro totals asynchronously and renders a compact
/// "P · C · F" chip. Tapping cycles between grams and % of meal kcal.
class _MealMacroSummary extends ConsumerWidget {
  final List<FoodEntryData> entries;
  final bool showPercent;
  final VoidCallback onToggle;

  const _MealMacroSummary({
    required this.entries,
    required this.showPercent,
    required this.onToggle,
  });

  Future<DailyTotals> _sumMacros(NutritionRepository repo) async {
    var t = DailyTotals.empty;
    for (final e in entries) {
      final m = await repo.macrosForEntry(e);
      t = t.plus(
        kcal: m.kcal,
        proteinG: m.proteinG,
        carbsG: m.carbsG,
        fatG: m.fatG,
      );
    }
    return t;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(nutritionRepositoryProvider);
    final theme = Theme.of(context);

    return FutureBuilder<DailyTotals>(
      future: _sumMacros(repo),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final t = snap.data!;
        final totalKcal = t.kcal;

        String fmt(double grams, double kcalPer1g) {
          if (showPercent && totalKcal > 0) {
            final pct = (grams * kcalPer1g / totalKcal * 100).round();
            return '$pct%';
          }
          return '${grams.toStringAsFixed(0)}g';
        }

        return GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MacroChip('P', fmt(t.proteinG, 4),
                    const Color(0xFF4FC3F7), theme),
                const SizedBox(width: 6),
                _MacroChip('C', fmt(t.carbsG, 4),
                    const Color(0xFF81C784), theme),
                const SizedBox(width: 6),
                _MacroChip('F', fmt(t.fatG, 9),
                    const Color(0xFFFFB74D), theme),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  const _MacroChip(this.label, this.value, this.color, this.theme);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      future: _resolve(ref, repo),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            dense: true,
            title: Text(display?.name ?? 'Loading…',
                style: theme.textTheme.bodyMedium),
            subtitle: Text(
              display?.subtitle ?? '',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondary),
            ),
            trailing: Text(
              display == null ? '' : '${display.kcal.toStringAsFixed(0)} kcal',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onTap: display == null
                ? null
                : () => _showEntryDetail(context, theme, display),
          ),
        );
      },
    );
  }

  Future<_EntryDisplay> _resolve(
      WidgetRef ref, NutritionRepository repo) async {
    final macros = await repo.macrosForEntry(entry);
    final name = await _resolveName(ref);
    final subtitle = entry.foodId != null
        ? '${(entry.gramsOverride ?? 0).toStringAsFixed(0)} g'
        : '${entry.servings.toStringAsFixed(entry.servings.truncateToDouble() == entry.servings ? 0 : 1)} serv';
    return _EntryDisplay(
      name: name,
      subtitle: subtitle,
      kcal: macros.kcal,
      sodiumMg: macros.sodiumMg,
      potassiumMg: macros.potassiumMg,
      cholesterolMg: macros.cholesterolMg,
    );
  }

  void _showEntryDetail(
      BuildContext context, ThemeData theme, _EntryDisplay display) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final hasMicros = display.sodiumMg > 0 ||
            display.potassiumMg > 0 ||
            display.cholesterolMg > 0;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
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
              Text(display.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(display.subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondary)),
              const SizedBox(height: 20),
              Text(
                '${display.kcal.toStringAsFixed(0)} kcal',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (hasMicros) ...[
                const SizedBox(height: 16),
                Text('MINERALS',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary, letterSpacing: 1.0)),
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
      return list
          .firstWhere(
            (f) => f.id == entry.foodId,
            orElse: () => _placeholderFood(),
          )
          .name;
    }
    if (entry.recipeId != null) {
      final list = await ref.read(recipesProvider.future);
      return list
          .firstWhere(
            (r) => r.id == entry.recipeId,
            orElse: () => _placeholderRecipe(),
          )
          .name;
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
                  const Icon(Icons.science_outlined,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text('MINERALS',
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary, letterSpacing: 1.0)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppColors.secondary),
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
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.secondary)),
        Text('${value.toStringAsFixed(0)} $unit',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
