import 'dart:math';

import '../../../data/local/database.dart';

class MuscleRecoveryResult {
  final String muscle;
  final double score; // 0.0 (fully recovered) to 1.0 (highly fatigued)

  const MuscleRecoveryResult(this.muscle, this.score);

  String get status {
    if (score < 0.3) return "RECOVERED";
    if (score < 0.7) return "RECOVERING";
    return "FATIGUED";
  }
}

class MuscleRecovery {
  /// Computes dynamic fatigue score (0 to 1) for each muscle group based on sets completed.
  /// Fatigue decays exponentially over 72 hours. High RPE sets increase fatigue.
  static List<MuscleRecoveryResult> compute({
    required List<SetEntryData> sets,
    required List<WorkoutExerciseData> workoutExercises,
    required List<ExerciseCatalogData> catalog,
    required DateTime asOf,
  }) {
    final muscles = ['Chest', 'Back', 'Shoulders', 'Quads', 'Hamstrings', 'Arms', 'Abs'];
    final Map<String, double> fatigueScores = {for (var m in muscles) m: 0.0};

    // Index mappings
    final exerciseMap = {for (var ex in catalog) ex.id: ex};
    final weMap = {for (var we in workoutExercises) we.id: we};

    for (final set in sets) {
      if (!set.isCompleted || set.completedAt == null) continue;

      final we = weMap[set.workoutExerciseId];
      if (we == null) continue;

      final ex = exerciseMap[we.exerciseId];
      if (ex == null) continue;

      final muscle = ex.primaryMuscle;
      if (!fatigueScores.containsKey(muscle)) continue;

      final hoursDiff = asOf.difference(set.completedAt!).inHours;
      if (hoursDiff > 72) continue; // fully decayed

      // Base fatigue weight for a working set is 0.15
      double baseFatigue = 0.15;

      // Adjust for RPE (RPE >= 8 adds +50% fatigue)
      final rpe = set.rpeX10 != null ? set.rpeX10! / 10.0 : 7.0;
      if (rpe >= 8) {
        baseFatigue *= 1.5;
      }

      // Exponential decay: fatigue = base * e^(-t / 24) (half-life of 24h)
      final decay = exp(-hoursDiff / 24.0);
      final decayedFatigue = baseFatigue * decay;

      fatigueScores[muscle] = (fatigueScores[muscle]! + decayedFatigue).clamp(0.0, 1.0);
    }

    return fatigueScores.entries
        .map((e) => MuscleRecoveryResult(e.key, e.value))
        .toList();
  }
}
