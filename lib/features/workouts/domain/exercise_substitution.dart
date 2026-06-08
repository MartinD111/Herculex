import '../../../data/local/database.dart';

class ExerciseSubstitution {
  /// Calculates the matching score between an [original] exercise and a [candidate].
  /// Returns a Map containing:
  /// - 'score': the total score used for sorting (including history boost)
  /// - 'percentage': the base biomechanical match percentage (0 to 100)
  /// - 'isHistoryMatch': whether the user has recently performed this exercise
  static Map<String, dynamic> calculateMatch({
    required ExerciseCatalogData original,
    required ExerciseCatalogData candidate,
    required Set<int> recentExerciseIds,
  }) {
    if (original.id == candidate.id) {
      return {'score': 0.0, 'percentage': 0.0, 'isHistoryMatch': false};
    }

    // Strict constraint: Force vector must match (never substitute pull with push or static)
    if (original.force.toLowerCase() != candidate.force.toLowerCase()) {
      return {'score': 0.0, 'percentage': 0.0, 'isHistoryMatch': false};
    }

    double baseScore = 0.0;

    // Mechanics match (isolation vs compound): 40 points
    if (original.mechanics.toLowerCase() == candidate.mechanics.toLowerCase()) {
      baseScore += 40.0;
    }

    // Movement plane match: 30 points
    if (original.plane.toLowerCase() == candidate.plane.toLowerCase()) {
      baseScore += 30.0;
    }

    // Primary muscle match: 30 points
    if (original.primaryMuscle.toLowerCase() == candidate.primaryMuscle.toLowerCase()) {
      baseScore += 30.0;
    }

    final isHistoryMatch = recentExerciseIds.contains(candidate.id);
    // History boost: +50 points to rank it higher in the suggestions list
    final totalScore = baseScore + (isHistoryMatch ? 50.0 : 0.0);

    return {
      'score': totalScore,
      'percentage': (baseScore / 100.0) * 100.0,
      'isHistoryMatch': isHistoryMatch,
    };
  }

  /// Takes the original exercise, a list of all candidates from the catalog,
  /// and the user's recent exercise history, returning a list of ranked substitute candidates.
  static List<RankedSubstitution> getRankedSubstitutes({
    required ExerciseCatalogData original,
    required List<ExerciseCatalogData> candidates,
    required Set<int> recentExerciseIds,
  }) {
    final List<RankedSubstitution> results = [];

    for (final candidate in candidates) {
      if (candidate.id == original.id) continue;

      final match = calculateMatch(
        original: original,
        candidate: candidate,
        recentExerciseIds: recentExerciseIds,
      );

      final double score = match['score'] as double;
      final double percentage = match['percentage'] as double;
      final bool isHistoryMatch = match['isHistoryMatch'] as bool;

      // Only include candidates that have some biomechanical overlap (e.g. force matches)
      if (score > 0) {
        results.add(RankedSubstitution(
          exercise: candidate,
          score: score,
          percentage: percentage.round(),
          isHistoryMatch: isHistoryMatch,
        ));
      }
    }

    // Sort descending by score (highest match & recently performed first)
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}

class RankedSubstitution {
  final ExerciseCatalogData exercise;
  final double score;
  final int percentage;
  final bool isHistoryMatch;

  const RankedSubstitution({
    required this.exercise,
    required this.score,
    required this.percentage,
    required this.isHistoryMatch,
  });
}
