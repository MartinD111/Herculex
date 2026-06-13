import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../theme/haptics.dart';
import '../../profile/domain/profile.dart';
import '../domain/progression_engine.dart';
import '../domain/set_type.dart';
import 'accessory_tray_sheet.dart';
import 'equipment_variant_sheet.dart';
import 'exercise_performance_sheet.dart';
import 'machine_config_sheet.dart';
import 'progression_override_sheet.dart';
import 'rest_timer_controller.dart';
import 'set_type_menu.dart';
import 'smart_substitution_sheet.dart';
import 'workouts_providers.dart';

class ActiveExerciseCard extends ConsumerWidget {
  final WorkoutExerciseData workoutExercise;
  final ExerciseCatalogData exercise;
  final VoidCallback onRemove;

  const ActiveExerciseCard({
    super.key,
    required this.workoutExercise,
    required this.exercise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sets = ref.watch(setsForWorkoutExerciseProvider(workoutExercise.id));
    final lastPerformance = ref.watch(lastPerformanceProvider(exercise.id));
    final repo = ref.watch(workoutsRepositoryProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.primaryMuscle} • ${EquipmentVariantSheet.labelFor(workoutExercise.equipmentVariant ?? exercise.modality)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showMenu(context, ref),
              ),
            ],
          ),
          lastPerformance.maybeWhen(
            data: (sets) => sets.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last: ${_formatLast(sets)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _nextTargetHint(theme, ref, sets),
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _HeaderRow(theme: theme),
          sets.when(
            data: (rows) => Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _SetRow(
                    index: i + 1,
                    set: rows[i],
                    onUpdate: (weight, reps, rpeX10) => repo.updateSet(
                      setId: rows[i].id,
                      weightKg: weight,
                      reps: reps,
                      rpeX10: rpeX10,
                    ),
                    onComplete: (completed) async {
                      await repo.updateSet(setId: rows[i].id, isCompleted: completed);
                      if (completed) {
                        final rest = workoutExercise.targetRestSeconds ?? exercise.defaultRestSeconds;
                        ref.read(restTimerProvider.notifier).start(
                          seconds: rest,
                          exerciseName: exercise.name,
                        );
                      }
                    },
                    onDelete: () => repo.deleteSet(rows[i].id),
                    // One-tap set-type switch (§15, §26).
                    onTypeTap: () async {
                      final sel = await SetTypeMenu.show(
                        context,
                        current: SetType.fromId(rows[i].setType),
                      );
                      if (sel != null) {
                        await repo.updateSet(
                          setId: rows[i].id,
                          setType: sel.type.id,
                          setTypeMetaJson: sel.metaJson,
                        );
                      }
                    },
                    // Accessory quick-tray (§5–§8, §26).
                    onAccessories: () =>
                        AccessoryTraySheet.show(context, rows[i]),
                  ),
              ],
            ),
            error: (e, _) => Text('Error: $e'),
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              // Default new set to last set's values for fast logging.
              final rows = sets.asData?.value ?? const [];
              final prev = rows.isNotEmpty ? rows.last : null;
              // Weighted bodyweight (§9): snapshot current BW so total load
              // (added weight + body) feeds volume/1RM correctly.
              double? bodyweight = prev?.bodyweightKg;
              if (exercise.supportsWeightedBodyweight && bodyweight == null) {
                bodyweight = await ref
                    .read(measurementsRepositoryProvider)
                    .latestBodyweightKg();
              }
              final newSetId = await repo.addSet(
                workoutExerciseId: workoutExercise.id,
                weightKg: prev?.weightKg ?? 0,
                reps: prev?.reps ?? 0,
                rpeX10: prev?.rpeX10,
                isWarmup: prev?.isWarmup ?? false,
                setType: prev?.setType ?? 'standard',
                setTypeMetaJson: prev?.setTypeMetaJson,
                bodyweightKg: bodyweight,
                chainsKg: prev?.chainsKg,
              );
              // Carry the accessory selection forward (§26) so belt/sleeves
              // don't need re-tapping every set.
              if (prev != null) {
                await ref.read(accessoriesRepositoryProvider).copySetAccessories(
                      fromSetId: prev.id,
                      toSetId: newSetId,
                    );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Set'),
          ),
        ],
      ),
    );
  }

  /// Suggested next-workout target (§16): best set from last session run
  /// through the progression engine. Per-exercise override takes priority over
  /// the profile goal.
  Widget _nextTargetHint(
      ThemeData theme, WidgetRef ref, List<SetEntryData> lastSets) {
    final best = lastSets
        .reduce((a, b) => a.weightKg * a.reps >= b.weightKg * b.reps ? a : b);
    final override =
        ref.watch(exerciseProgressionProvider(exercise.id)).asData?.value;
    final ProgressionGoal goal;
    final double? weeklyPctOverride;
    if (override != null && override.enabled) {
      goal = ProgressionGoal.values.firstWhere(
        (g) => g.name == override.goal,
        orElse: () => ProgressionGoal.muscleGain,
      );
      weeklyPctOverride = override.weeklyIncreasePct;
    } else {
      final fitnessGoal =
          ref.watch(profileProvider).asData?.value?.goal ?? FitnessGoal.maintenance;
      goal = switch (fitnessGoal) {
        FitnessGoal.weightLoss => ProgressionGoal.fatLoss,
        FitnessGoal.muscleGain ||
        FitnessGoal.maintenance =>
          ProgressionGoal.muscleGain,
        FitnessGoal.improveHealth => ProgressionGoal.endurance,
      };
      weeklyPctOverride = null;
    }
    final target = ProgressionEngine.suggestNext(
      lastWeightKg: best.weightKg,
      lastReps: best.reps,
      goal: goal,
      equipmentVariant: workoutExercise.equipmentVariant ?? exercise.modality,
      weeklyIncreasePctOverride: weeklyPctOverride,
    );
    if (target.weightKg <= 0 && best.weightKg <= 0) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: target.rationale,
      child: Text(
        'Next: ${target.weightKg.toStringAsFixed(target.weightKg.truncateToDouble() == target.weightKg ? 0 : 1)}kg × ${target.reps}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatLast(List<SetEntryData> sets) {
    return sets
        .map((s) {
          final rpe = s.rpeX10 != null ? ' @${(s.rpeX10! / 10).toStringAsFixed(1)}' : '';
          return '${s.weightKg.toStringAsFixed(s.weightKg.truncateToDouble() == s.weightKg ? 0 : 1)}kg × ${s.reps}$rpe';
        })
        .join(' • ');
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final isMachine = (workoutExercise.equipmentVariant ?? exercise.modality)
        .startsWith('machine');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('View performance'),
              subtitle: const Text('PRs per equipment & accessory combo'),
              onTap: () {
                Navigator.pop(context);
                ExercisePerformanceSheet.show(context, exercise);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Change equipment'),
              subtitle: Text(EquipmentVariantSheet.labelFor(
                  workoutExercise.equipmentVariant ?? exercise.modality)),
              onTap: () async {
                Navigator.pop(context);
                final variant =
                    await EquipmentVariantSheet.show(context, exercise);
                if (variant != null) {
                  await ref.read(workoutsRepositoryProvider).setEquipmentVariant(
                        workoutExerciseId: workoutExercise.id,
                        equipmentVariant: variant,
                      );
                }
              },
            ),
            if (isMachine || workoutExercise.machineConfigJson != null)
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Machine settings'),
                subtitle: const Text('Seat, angle, lever position…'),
                onTap: () {
                  Navigator.pop(context);
                  final gymId = ref.read(activeSessionProvider).asData?.value?.gymId;
                  MachineConfigSheet.show(
                    context,
                    workoutExercise: workoutExercise,
                    gymId: gymId,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Set progression goal'),
              subtitle: const Text('Override rep range & weekly load increase'),
              onTap: () {
                Navigator.pop(context);
                ProgressionOverrideSheet.show(
                  context,
                  exerciseId: exercise.id,
                  exerciseName: exercise.name,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Substitute exercise'),
              onTap: () {
                Navigator.pop(context);
                SmartSubstitutionSheet.show(
                  context,
                  workoutExercise: workoutExercise,
                  originalExercise: exercise,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove exercise'),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final ThemeData theme;
  const _HeaderRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final s = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.secondary,
      letterSpacing: 1.0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('SET', style: s)),
          const SizedBox(width: 8),
          Expanded(child: Text('KG', style: s, textAlign: TextAlign.center)),
          Expanded(child: Text('REPS', style: s, textAlign: TextAlign.center)),
          Expanded(child: Text('RPE', style: s, textAlign: TextAlign.center)),
          const SizedBox(width: 78),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final SetEntryData set;
  final Future<void> Function(double? weight, int? reps, int? rpeX10) onUpdate;
  final Future<void> Function(bool completed) onComplete;
  final VoidCallback onDelete;
  final VoidCallback onTypeTap;
  final VoidCallback onAccessories;

  const _SetRow({
    required this.index,
    required this.set,
    required this.onUpdate,
    required this.onComplete,
    required this.onDelete,
    required this.onTypeTap,
    required this.onAccessories,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _rpe;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _fmtWeight(widget.set.weightKg));
    _reps = TextEditingController(text: widget.set.reps == 0 ? '' : widget.set.reps.toString());
    _rpe = TextEditingController(
      text: widget.set.rpeX10 == null ? '' : (widget.set.rpeX10! / 10).toStringAsFixed(1),
    );
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync if upstream value diverged (e.g. duplicated from prev set).
    if (oldWidget.set.weightKg != widget.set.weightKg) {
      _weight.text = _fmtWeight(widget.set.weightKg);
    }
    if (oldWidget.set.reps != widget.set.reps) {
      _reps.text = widget.set.reps == 0 ? '' : widget.set.reps.toString();
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rpe.dispose();
    super.dispose();
  }

  String _fmtWeight(double v) {
    if (v == 0) return '';
    return v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  /// Set index cell: warmups show 'W', non-standard set types show their
  /// badge ('D' drop, 'RP' rest-pause, …), plain sets show the number.
  String _indexLabel() {
    if (widget.set.isWarmup) return 'W';
    final type = SetType.fromId(widget.set.setType);
    final badge = SetTypeMenu.badge(type);
    return badge.isEmpty ? '${widget.index}' : badge;
  }

  Color _indexColor() {
    if (widget.set.isWarmup) return AppColors.outline;
    if (SetType.fromId(widget.set.setType) != SetType.standard) {
      return AppColors.primary;
    }
    return AppColors.onSurface;
  }

  void _commit() {
    final w = double.tryParse(_weight.text);
    final r = int.tryParse(_reps.text);
    final rpe = double.tryParse(_rpe.text);
    widget.onUpdate(w, r, rpe == null ? null : (rpe * 10).round());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = widget.set.isCompleted;
    final color = isCompleted ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent;

    return Dismissible(
      key: ValueKey('set_${widget.set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.redAccent.withValues(alpha: 0.85),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            // Tapping the set index switches the set type (§15, §26).
            InkWell(
              onTap: widget.onTypeTap,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 28,
                height: 32,
                child: Center(
                  child: Text(
                    _indexLabel(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _indexColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _numberField(_weight, decimal: true)),
            const SizedBox(width: 8),
            Expanded(child: _numberField(_reps)),
            const SizedBox(width: 8),
            Expanded(child: _numberField(_rpe, decimal: true)),
            // Accessory quick-tray (§26): belt/bands/chains without leaving
            // the set.
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: Icon(
                Icons.construction,
                size: 18,
                color: widget.set.chainsKg != null
                    ? AppColors.primary
                    : AppColors.outline,
              ),
              tooltip: 'Accessories',
              onPressed: widget.onAccessories,
            ),
            GestureDetector(
              onTap: () {
                Haptics.medium();
                _commit();
                widget.onComplete(!isCompleted);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isCompleted ? AppColors.primary : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl, {bool decimal = false}) {
    return TextField(
      controller: ctrl,
      onEditingComplete: _commit,
      onTapOutside: (_) => _commit(),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        filled: true,
        fillColor: AppColors.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
