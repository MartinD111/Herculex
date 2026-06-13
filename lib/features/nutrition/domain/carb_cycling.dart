/// Carb level for a day in the cycle (§19).
enum CarbLevel {
  high('high', 'High'),
  medium('med', 'Medium'),
  low('low', 'Low');

  const CarbLevel(this.id, this.label);
  final String id;
  final String label;

  static CarbLevel fromId(String id) =>
      values.firstWhere((l) => l.id == id, orElse: () => CarbLevel.medium);
}

/// Per-day training signal feeding the carb-cycle generator. [compoundDensity]
/// is the share of the day's working sets that are heavy compound movements
/// (0–1); [cnsLoad] is that day's CNS load (raw units from CnsTrends).
class DayTrainingSignal {
  final int weekdayIndex; // 0 = Monday … 6 = Sunday
  final double compoundDensity;
  final double cnsLoad;
  final bool isTrainingDay;

  const DayTrainingSignal({
    required this.weekdayIndex,
    this.compoundDensity = 0,
    this.cnsLoad = 0,
    this.isTrainingDay = false,
  });
}

/// Carb-cycling engine (§19). Analyses the week's training (CNS load +
/// compound density) and recommends High/Medium/Low carb days: the hardest,
/// most compound-heavy, highest-CNS days get the most carbs to fuel/recover
/// them; rest days get the fewest.
class CarbCycling {
  /// Returns the carb level per day, Monday→Sunday (length 7).
  static List<CarbLevel> generate(List<DayTrainingSignal> week) {
    assert(week.length == 7);

    // Score each day: training days score on CNS + compound emphasis; rest
    // days score 0 (→ low).
    final scores = [
      for (final d in week)
        d.isTrainingDay ? d.cnsLoad * (1 + d.compoundDensity) : 0.0,
    ];

    final trainingScores = [
      for (var i = 0; i < 7; i++)
        if (week[i].isTrainingDay) scores[i],
    ]..sort();

    if (trainingScores.isEmpty) {
      // No training info → flat medium week.
      return List.filled(7, CarbLevel.medium);
    }

    // Thresholds at the tertiles of training-day scores.
    final lowCut = _percentile(trainingScores, 1 / 3);
    final highCut = _percentile(trainingScores, 2 / 3);

    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = week[i];
          if (!d.isTrainingDay) return CarbLevel.low;
          final s = scores[i];
          if (s >= highCut) return CarbLevel.high;
          if (s <= lowCut) return CarbLevel.low;
          return CarbLevel.medium;
        }(),
    ];
  }

  /// Carb grams for a level relative to a baseline (medium) carb target.
  /// High = +30%, Low = −35%; protein/fat are managed elsewhere.
  static int carbsForLevel(CarbLevel level, int baselineCarbsG) {
    final factor = switch (level) {
      CarbLevel.high => 1.30,
      CarbLevel.medium => 1.0,
      CarbLevel.low => 0.65,
    };
    return (baselineCarbsG * factor).round();
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final idx = (p * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }
}
