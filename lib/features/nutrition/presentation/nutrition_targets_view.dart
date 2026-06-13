import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colors.dart';
import '../data/carb_cycle_service.dart';
import '../domain/carb_cycling.dart';
import 'nutrition_providers.dart';

/// Nutrition targets, automated dieting, and carb cycling (§19). All
/// edit/save actions are bottom-anchored per §22.
class NutritionTargetsView extends ConsumerWidget {
  const NutritionTargetsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final targets = ref.watch(nutritionTargetsProvider);
    final schedule = ref.watch(activeDietScheduleProvider);
    final today = DateTime.now();
    final carbCycle = ref.watch(
        generatedCarbCycleProvider(DateTime(today.year, today.month, today.day)));

    return Scaffold(
      appBar: AppBar(title: const Text('Targets & Dieting')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            // ── Day-specific targets ──
            _SectionTitle('Daily Targets'),
            Text(
              'Set a global target, or scope by training day, rest day, or weekday. The most specific match wins.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            targets.when(
              data: (rows) => Column(
                children: [
                  for (final t in rows)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        title: Text('${t.label} · ${_scopeLabel(t.appliesTo)}'),
                        subtitle: Text(
                            '${t.kcal} kcal · P${t.proteinG} C${t.carbsG} F${t.fatG}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => ref
                              .read(nutritionRepositoryProvider)
                              .deleteTarget(t.id),
                        ),
                      ),
                    ),
                  if (rows.isEmpty)
                    Text('Using profile-calculated targets.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.secondary)),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // ── Automated dieting ──
            _SectionTitle('Automated Cut'),
            schedule.when(
              data: (s) => s == null
                  ? Text(
                      'No active schedule. Reduce calories on a fixed cadence to automate a cut.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary))
                  : Card(
                      child: ListTile(
                        leading: const Icon(Icons.trending_down,
                            color: AppColors.primary),
                        title: Text(
                            '−${s.reducePct.toStringAsFixed(1)}% every ${s.intervalDays} days'),
                        subtitle: Text('Since ${s.startDateIso}'),
                        trailing: TextButton(
                          onPressed: () => ref
                              .read(nutritionRepositoryProvider)
                              .stopDietSchedules(),
                          child: const Text('Stop'),
                        ),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // ── Carb cycling ──
            _SectionTitle('Carb Cycle (this week)'),
            Text(
              'Generated from your training: hardest, most compound-heavy days get the most carbs.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            carbCycle.when(
              data: (levels) => _CarbCycleRow(levels: levels),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Save this week\'s plan'),
              onPressed: () async {
                final levels = carbCycle.asData?.value;
                if (levels == null) return;
                final monday = _mondayOf(today);
                await ref.read(nutritionRepositoryProvider).saveCarbCyclePlan(
                      weekStart: monday,
                      dayLevelsJson: CarbCycleService.encodeLevels(levels),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Carb cycle saved')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      // Bottom-anchored primary actions (§22).
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _startCutDialog(context, ref),
                  child: const Text('Start Cut'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _editTargetDialog(context, ref),
                  child: const Text('Add Target'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(String appliesTo) {
    if (appliesTo == 'global') return 'Global';
    if (appliesTo == 'training_day') return 'Training day';
    if (appliesTo == 'rest_day') return 'Rest day';
    if (appliesTo.startsWith('weekday:')) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final n = int.tryParse(appliesTo.substring(8)) ?? 1;
      return names[(n - 1).clamp(0, 6)];
    }
    if (appliesTo.startsWith('date:')) return appliesTo.substring(5);
    return appliesTo;
  }

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  Future<void> _editTargetDialog(BuildContext context, WidgetRef ref) async {
    var scope = 'global';
    final kcal = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final fat = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('Add target'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text('Global')),
                    DropdownMenuItem(
                        value: 'training_day', child: Text('Training day')),
                    DropdownMenuItem(
                        value: 'rest_day', child: Text('Rest day')),
                  ],
                  onChanged: (v) => setState(() => scope = v ?? 'global'),
                ),
                _numField(kcal, 'Calories (kcal)'),
                _numField(protein, 'Protein (g)'),
                _numField(carbs, 'Carbs (g)'),
                _numField(fat, 'Fat (g)'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await ref.read(nutritionRepositoryProvider).upsertTarget(
          label: _scopeLabel(scope),
          appliesTo: scope,
          kcal: int.tryParse(kcal.text) ?? 0,
          proteinG: int.tryParse(protein.text) ?? 0,
          carbsG: int.tryParse(carbs.text) ?? 0,
          fatG: int.tryParse(fat.text) ?? 0,
        );
  }

  Future<void> _startCutDialog(BuildContext context, WidgetRef ref) async {
    final pct = TextEditingController(text: '5');
    final interval = TextEditingController(text: '14');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Start automated cut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numField(pct, 'Reduce by (%)'),
            _numField(interval, 'Every (days)'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Start')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(nutritionRepositoryProvider).startDietSchedule(
          startDate: DateTime.now(),
          reducePct: double.tryParse(pct.text) ?? 5,
          intervalDays: int.tryParse(interval.text) ?? 14,
        );
  }

  static Widget _numField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _CarbCycleRow extends StatelessWidget {
  final List<CarbLevel> levels;
  const _CarbCycleRow({required this.levels});

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < levels.length && i < 7; i++)
          Expanded(
            child: Column(
              children: [
                Text(days[i],
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _color(levels[i]).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _color(levels[i])),
                  ),
                  alignment: Alignment.center,
                  child: Text(levels[i].label[0],
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _color(levels[i]))),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _color(CarbLevel l) => switch (l) {
        CarbLevel.high => Colors.green,
        CarbLevel.medium => Colors.amber,
        CarbLevel.low => Colors.redAccent,
      };
}
