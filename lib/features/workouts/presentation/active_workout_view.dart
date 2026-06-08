import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../widgets/premium_button.dart';
import 'active_exercise_card.dart';
import 'exercise_picker_sheet.dart';
import 'rest_timer_banner.dart';
import 'workouts_providers.dart';

class ActiveWorkoutView extends ConsumerWidget {
  final WorkoutSessionData session;
  const ActiveWorkoutView({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionExercises = ref.watch(sessionExercisesProvider(session.id));
    final catalog = ref.watch(exerciseCatalogProvider(null));
    final repo = ref.watch(workoutsRepositoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workout in progress', style: theme.textTheme.displayMedium?.copyWith(fontSize: 22)),
                    Text(
                      _elapsed(session.startedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel workout',
                onPressed: () => _confirmCancel(context, ref),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: RestTimerBanner(),
        ),
        Expanded(
          child: sessionExercises.when(
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 56, color: AppColors.primary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No exercises yet', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
                      const SizedBox(height: 8),
                      Text('Tap + Add Exercise to start logging', style: theme.textTheme.bodySmall),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 220),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final we = rows[i];
                  final exercise = catalog.asData?.value.firstWhere(
                    (e) => e.id == we.exerciseId,
                    orElse: () => _placeholderExercise(we.exerciseId),
                  );
                  if (exercise == null) {
                    return const SizedBox.shrink();
                  }
                  return ActiveExerciseCard(
                    workoutExercise: we,
                    exercise: exercise,
                    onRemove: () => repo.removeWorkoutExercise(we.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 104),
            child: Row(
              children: [
                Expanded(
                  child: PremiumButton(
                    text: 'Add Exercise',
                    icon: Icons.add,
                    isPrimary: false,
                    onTap: () async {
                      final picked = await ExercisePickerSheet.show(context);
                      if (picked != null) {
                        await repo.addExerciseToSession(
                          sessionId: session.id,
                          exerciseId: picked.id,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton(
                    text: 'Finish',
                    icon: Icons.check,
                    onTap: () async {
                      await repo.endSession(session.id);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _elapsed(DateTime startedAt) {
    final d = DateTime.now().difference(startedAt);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  ExerciseCatalogData _placeholderExercise(int id) => ExerciseCatalogData(
        id: id,
        name: 'Loading…',
        primaryMuscle: '',
        equipment: '',
        mechanics: '',
        force: '',
        plane: '',
        defaultRestSeconds: 120,
        isCustom: false,
        category: 'strength',
        modality: 'barbell',
        cnsScore: 3,
        recoveryImpact: 3,
        loggingMetric: 'weight_reps',
        supportsWeightedBodyweight: false,
        isReviewed: false,
      );

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This deletes the in-progress session and its sets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          TextButton(
            onPressed: () async {
              await ref.read(workoutsRepositoryProvider).deleteSession(session.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
