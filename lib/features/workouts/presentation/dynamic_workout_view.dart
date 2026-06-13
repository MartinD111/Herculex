import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import 'equipment_variant_sheet.dart';
import 'rest_timer_controller.dart';
import 'workouts_providers.dart';

/// Dynamic workout mode (§14): full-screen, distraction-free view with a
/// large exercise display, big timer, and big rep/set counters. One tap
/// returns to the Classic view.
class DynamicWorkoutView extends ConsumerStatefulWidget {
  final WorkoutSessionData session;
  const DynamicWorkoutView({super.key, required this.session});

  @override
  ConsumerState<DynamicWorkoutView> createState() => _DynamicWorkoutViewState();
}

class _DynamicWorkoutViewState extends ConsumerState<DynamicWorkoutView> {
  int _exerciseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises =
        ref.watch(sessionExercisesProvider(widget.session.id)).asData?.value ??
            const <WorkoutExerciseData>[];
    final catalog =
        ref.watch(exerciseCatalogProvider(null)).asData?.value ?? const [];
    final restTimer = ref.watch(restTimerProvider);

    if (_exerciseIndex >= exercises.length && exercises.isNotEmpty) {
      _exerciseIndex = exercises.length - 1;
    }
    final we = exercises.elementAtOrNull(_exerciseIndex);
    final exercise =
        we == null ? null : catalog.firstWhereOrNull((e) => e.id == we.exerciseId);
    final sets = we == null
        ? const <SetEntryData>[]
        : ref.watch(setsForWorkoutExerciseProvider(we.id)).asData?.value ??
            const <SetEntryData>[];
    final nextSet = sets.firstWhereOrNull((s) => !s.isCompleted);
    final completedCount = sets.where((s) => s.isCompleted).length;

    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.fullscreen_exit),
                tooltip: 'Classic mode',
                onPressed: () =>
                    ref.read(dynamicWorkoutModeProvider.notifier).state = false,
              ),
              const Spacer(),
              if (exercises.length > 1) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  onPressed: _exerciseIndex > 0
                      ? () => setState(() => _exerciseIndex--)
                      : null,
                ),
                Text('${_exerciseIndex + 1}/${exercises.length}',
                    style: theme.textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 32),
                  onPressed: _exerciseIndex < exercises.length - 1
                      ? () => setState(() => _exerciseIndex++)
                      : null,
                ),
              ],
            ],
          ),
          Expanded(
            child: exercise == null
                ? Center(
                    child: Text('Add exercises in Classic mode',
                        style: theme.textTheme.titleMedium))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          exercise.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium
                              ?.copyWith(fontSize: 34, height: 1.1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        EquipmentVariantSheet.labelFor(
                            we!.equipmentVariant ?? exercise.modality),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: AppColors.secondary),
                      ),
                      const SizedBox(height: 32),
                      // Big rest timer or big set counter.
                      if (restTimer.isRunning)
                        Text(
                          _fmtSeconds(
                              restTimer.remainingSecondsFrom(DateTime.now())),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 88,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      else
                        Text(
                          'SET ${completedCount + (nextSet != null ? 1 : 0)}/${sets.length}',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (nextSet != null)
                        Text(
                          '${_fmtWeight(nextSet.weightKg)} kg × ${nextSet.reps}',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontSize: 44,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        Text('All sets done 🎉',
                            style: theme.textTheme.titleLarge),
                    ],
                  ),
          ),
          if (we != null && nextSet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 110),
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final repo = ref.read(workoutsRepositoryProvider);
                    final ex = exercise!;
                    await repo.updateSet(setId: nextSet.id, isCompleted: true);
                    ref.read(restTimerProvider.notifier).start(
                          seconds:
                              we.targetRestSeconds ?? ex.defaultRestSeconds,
                          exerciseName: ex.name,
                        );
                  },
                  child: const Text('COMPLETE SET',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtSeconds(int s) =>
      '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _fmtWeight(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
