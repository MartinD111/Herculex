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

/// A typed advisory surfaced when a muscle group is likely under-recovered.
class RecoveryAdvisory {
  final String muscle;
  final double score;
  final String message;
  const RecoveryAdvisory(this.muscle, this.score, this.message);
}

/// Recovery engine v2. Aggregates fatigue across *all* involved muscles using
/// the normalized [ExerciseMuscleData] rows (primary / secondary / stabilizer),
/// weighted by role × contribution, then folds granular muscles into the
/// display groups the heatmap paints. Falls back to the legacy coarse
/// [ExerciseCatalogData.primaryMuscle] for exercises without muscle rows.
class MuscleRecovery {
  /// Role → fatigue weight. Tunable constants (validated against the prior
  /// primary-only behaviour: a primary muscle still contributes weight 1.0).
  static const roleWeight = {
    'primary': 1.0,
    'secondary': 0.5,
    'stabilizer': 0.2,
  };

  /// Granular / legacy muscle name → painted display group.
  static const displayGroup = <String, String>{
    // granular
    'Chest': 'Chest', 'Serratus': 'Chest',
    'Lats': 'Back', 'Rhomboids': 'Back', 'Traps': 'Back', 'Erectors': 'Back',
    'Front Delts': 'Shoulders', 'Side Delts': 'Shoulders',
    'Rear Delts': 'Shoulders',
    'Biceps': 'Arms', 'Brachialis': 'Arms', 'Triceps': 'Arms',
    'Forearms': 'Arms',
    'Quads': 'Quads', 'Adductors': 'Quads', 'Abductors': 'Quads',
    'Hamstrings': 'Hamstrings', 'Glutes': 'Hamstrings',
    'Calves': 'Calves', 'Tibialis': 'Calves',
    'Abs': 'Abs', 'Obliques': 'Abs', 'Hip Flexors': 'Abs', 'Core': 'Abs',
    'Neck': 'Neck',
    // legacy coarse values seeded before v8
    'Arms': 'Arms',
  };

  static const _groups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Quads', 'Hamstrings', 'Calves',
    'Abs', 'Neck',
  ];

  static List<MuscleRecoveryResult> compute({
    required List<SetEntryData> sets,
    required List<WorkoutExerciseData> workoutExercises,
    required List<ExerciseCatalogData> catalog,
    required List<ExerciseMuscleData> exerciseMuscles,
    required DateTime asOf,
  }) {
    final fatigue = {for (final g in _groups) g: 0.0};

    final exerciseMap = {for (final ex in catalog) ex.id: ex};
    final weMap = {for (final we in workoutExercises) we.id: we};
    final musclesByExercise = <int, List<ExerciseMuscleData>>{};
    for (final m in exerciseMuscles) {
      musclesByExercise.putIfAbsent(m.exerciseId, () => []).add(m);
    }

    for (final set in sets) {
      if (!set.isCompleted || set.completedAt == null) continue;
      final we = weMap[set.workoutExerciseId];
      if (we == null) continue;
      final ex = exerciseMap[we.exerciseId];
      if (ex == null) continue;

      final hoursDiff = asOf.difference(set.completedAt!).inHours;
      if (hoursDiff > 72) continue;

      double base = 0.15;
      final rpe = set.rpeX10 != null ? set.rpeX10! / 10.0 : 7.0;
      if (rpe >= 8) base *= 1.5;
      final perSet = base * exp(-hoursDiff / 24.0);

      final rows = musclesByExercise[ex.id];
      if (rows != null && rows.isNotEmpty) {
        for (final r in rows) {
          final group = displayGroup[r.muscle];
          if (group == null || !fatigue.containsKey(group)) continue;
          final w = (roleWeight[r.role] ?? 0.0) * r.contribution;
          fatigue[group] = (fatigue[group]! + perSet * w).clamp(0.0, 1.0);
        }
      } else {
        // Legacy fallback: treat the coarse primaryMuscle as a primary muscle.
        final group = displayGroup[ex.primaryMuscle] ?? ex.primaryMuscle;
        if (fatigue.containsKey(group)) {
          fatigue[group] = (fatigue[group]! + perSet).clamp(0.0, 1.0);
        }
      }
    }

    return fatigue.entries
        .map((e) => MuscleRecoveryResult(e.key, e.value))
        .toList();
  }

  /// Under-recovered muscle warnings (score ≥ [threshold]). Pure; consumed by
  /// the recovery dashboard.
  static List<RecoveryAdvisory> advisories(
    List<MuscleRecoveryResult> results, {
    double threshold = 0.7,
  }) {
    return [
      for (final r in results)
        if (r.score >= threshold)
          RecoveryAdvisory(r.muscle, r.score,
              '${r.muscle} is likely under-recovered — consider lighter volume or another day of rest.'),
    ];
  }
}
