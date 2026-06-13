import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import 'custom_exercise_builder_view.dart';
import 'workouts_providers.dart';

class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key});

  static Future<ExerciseCatalogData?> show(BuildContext context) {
    return showModalBottomSheet<ExerciseCatalogData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExercisePickerSheet(),
    );
  }

  @override
  ConsumerState<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  String? _query;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Collapses equipment variants of the same movement into one group while
  /// preserving the catalog's alphabetical order: a group takes the position of
  /// its first-seen member, and rows without a family stay standalone. Each
  /// group's variants are ordered with the base/free-weight option first.
  List<List<ExerciseCatalogData>> _groupByFamily(
      List<ExerciseCatalogData> list) {
    final groups = <List<ExerciseCatalogData>>[];
    final byFamily = <String, List<ExerciseCatalogData>>{};
    for (final e in list) {
      final fam = e.movementFamily;
      if (fam == null) {
        groups.add([e]);
        continue;
      }
      final existing = byFamily[fam];
      if (existing == null) {
        final group = <ExerciseCatalogData>[e];
        byFamily[fam] = group;
        groups.add(group);
      } else {
        existing.add(e);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = ref.watch(exerciseCatalogProvider(_query));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Exercise', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Custom'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    onPressed: () async {
                      final created = await CustomExerciseBuilderView.show(context);
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search exercises…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: exercises.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text('No exercises found',
                          style: theme.textTheme.bodyMedium),
                    );
                  }
                  final groups = _groupByFamily(list);
                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      if (g.length == 1) {
                        return _ExerciseTile(
                          exercise: g.first,
                          onTap: () => Navigator.of(context).pop(g.first),
                        );
                      }
                      return _FamilyTile(
                        variants: g,
                        onPick: (picked) => Navigator.of(context).pop(picked),
                      );
                    },
                  );
                },
                error: (e, _) => Center(child: Text('Failed to load: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collapsed movement that has multiple equipment variants. Tapping opens a
/// style chooser; the chosen real catalog row is returned to the picker caller.
class _FamilyTile extends StatelessWidget {
  final List<ExerciseCatalogData> variants;
  final ValueChanged<ExerciseCatalogData> onPick;
  const _FamilyTile({required this.variants, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = familyLabel(variants);
    final styles = variants.map((v) => v.equipment).toSet().toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final picked = await _StyleChooserSheet.show(context, label, variants);
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${variants.first.primaryMuscle} · ${styles.join(' / ')}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${variants.length} styles',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }

  /// Display name for the collapsed movement: the shared words across the
  /// variant names with equipment terms removed (e.g. "Incline Press"). Falls
  /// back to the shortest variant name if nothing meaningful remains.
  static String familyLabel(List<ExerciseCatalogData> variants) {
    String clean(String name) {
      var n = ' ${name.toLowerCase()} ';
      for (final t in _equipmentWords) {
        n = n.replaceAll(' $t ', ' ');
      }
      n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
      n = n.replaceAll('bench press', 'press').replaceAll('bench', 'press');
      return n.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final base = clean(variants.first.name);
    if (base.isEmpty) {
      return variants
          .map((v) => v.name)
          .reduce((a, b) => a.length <= b.length ? a : b);
    }
    // Title-case the cleaned base.
    return base
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static const _equipmentWords = <String>[
    'swiss bar', 'safety bar', 'axle bar', 'cambered bar', 'duffalo bar',
    'trap bar', 'hex bar', 'ez bar', 'ez-bar', 'landmine', 'meadows',
    'smith machine', 'smith', 'machine', 'cable', 'band-assisted', 'banded',
    'band', 'kettlebell', 'dumbbell', 'barbell', 'plate-loaded', 'plate',
    'iso-lateral', 'hammer', 'pendulum', 'v-squat', 'belt squat', 'sled',
    'yoke', 'rings', 'ring', 'trx', 'suspension', 'neck harness',
  ];
}

/// Equipment-style chooser shown after tapping a collapsed movement. Lists the
/// real catalog variants by their equipment label and returns the chosen row.
class _StyleChooserSheet extends StatelessWidget {
  final String movement;
  final List<ExerciseCatalogData> variants;
  const _StyleChooserSheet({required this.movement, required this.variants});

  static Future<ExerciseCatalogData?> show(
    BuildContext context,
    String movement,
    List<ExerciseCatalogData> variants,
  ) {
    return showModalBottomSheet<ExerciseCatalogData>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StyleChooserSheet(movement: movement, variants: variants),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor ??
            AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
              const SizedBox(height: 16),
              Text(movement,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Choose a style', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final v in variants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(v),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                AppColors.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center,
                              size: 20, color: AppColors.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.equipment,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                                Text(v.name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.secondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.add,
                              size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final ExerciseCatalogData exercise;
  final VoidCallback onTap;
  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.primaryMuscle} · ${exercise.equipment} · ${exercise.mechanics}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
