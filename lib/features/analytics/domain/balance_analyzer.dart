import '../../../data/local/database.dart';

class BalanceResult {
  final double pushPercentage;
  final double pullPercentage;
  final bool hasAsymmetry;

  const BalanceResult({
    required this.pushPercentage,
    required this.pullPercentage,
    required this.hasAsymmetry,
  });

  static const balanced = BalanceResult(
    pushPercentage: 50.0,
    pullPercentage: 50.0,
    hasAsymmetry: false,
  );
}

class BalanceAnalyzer {
  static BalanceResult summary({
    required List<SetEntryData> sets,
    required List<WorkoutExerciseData> workoutExercises,
    required List<ExerciseCatalogData> catalog,
  }) {
    // Index mapping
    final exerciseMap = {for (var ex in catalog) ex.id: ex};
    final weMap = {for (var we in workoutExercises) we.id: we};

    int pushSets = 0;
    int pullSets = 0;

    for (final set in sets) {
      if (!set.isCompleted) continue;

      final we = weMap[set.workoutExerciseId];
      if (we == null) continue;

      final ex = exerciseMap[we.exerciseId];
      if (ex == null) continue;

      final force = ex.force.toLowerCase();
      final muscle = ex.primaryMuscle.toLowerCase();

      if (force == 'push' || muscle == 'chest' || muscle == 'shoulders' || muscle == 'triceps') {
        pushSets++;
      } else if (force == 'pull' || muscle == 'back' || muscle == 'biceps') {
        pullSets++;
      }
    }

    final total = pushSets + pullSets;
    if (total == 0) {
      return BalanceResult.balanced;
    }

    final pushPct = (pushSets / total) * 100.0;
    final pullPct = (pullSets / total) * 100.0;

    final diff = (pushPct - pullPct).abs();
    final hasAsymmetry = diff > 25.0;

    return BalanceResult(
      pushPercentage: pushPct,
      pullPercentage: pullPct,
      hasAsymmetry: hasAsymmetry,
    );
  }
}
