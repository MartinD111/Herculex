import 'dart:math';

import 'training_snapshot.dart';

/// One day's accumulated CNS load (raw units: Σ cnsScore/10 × rpeFactor ×
/// setTypeFactor per working set).
class DailyCnsLoad {
  final DateTime day;
  final double load;
  const DailyCnsLoad(this.day, this.load);
}

class CnsTrendsResult {
  /// Trailing [days] of daily loads, oldest first (zero-filled).
  final List<DailyCnsLoad> daily;

  /// Current rolling fatigue 0–1 (same semantics as the v1 gauge).
  final double currentLoad;

  /// True when the acute (7-day) load exceeds the adaptive capacity implied
  /// by the chronic (28-day) average — classic ACWR > 1.4 deload trigger.
  final bool deloadSuggested;

  final double acuteWeeklyLoad;
  final double chronicWeeklyLoad;

  const CnsTrendsResult({
    required this.daily,
    required this.currentLoad,
    required this.deloadSuggested,
    required this.acuteWeeklyLoad,
    required this.chronicWeeklyLoad,
  });

  double get readiness => (1 - currentLoad).clamp(0.0, 1.0);

  String get status {
    if (currentLoad < 0.4) return 'FRESH';
    if (currentLoad < 0.7) return 'MODERATE';
    return 'HIGH';
  }

  String? get recommendation {
    if (deloadSuggested) {
      return 'CNS load is ${(acuteWeeklyLoad / (chronicWeeklyLoad == 0 ? 1 : chronicWeeklyLoad)).toStringAsFixed(1)}× your 4-week average — schedule a deload week.';
    }
    if (currentLoad >= 0.7) {
      return 'CNS fatigue is elevated. Consider reducing intensity or avoiding max-effort work today.';
    }
    return null;
  }
}

/// CNS engine v2 (V2 §3): daily/weekly load series and deload suggestions on
/// top of the rolling fatigue gauge. Uses [ResolvedSet.cnsScore], which
/// already applies the +2 weighted-bodyweight bump (§9).
class CnsTrends {
  static const _perSetBase = 0.08;
  static const _gaugeWindowHours = 96;
  static const _gaugeHalfLifeHours = 36.0;

  static CnsTrendsResult compute({
    required TrainingSnapshot snapshot,
    required DateTime asOf,
    int days = 28,
  }) {
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final dailyLoads = {
      for (var i = days - 1; i >= 0; i--)
        today.subtract(Duration(days: i)): 0.0,
    };
    var gauge = 0.0;

    for (final rs in snapshot.sets) {
      final completedAt = rs.set.completedAt;
      if (completedAt == null) continue;

      final intensity = rs.cnsScore / 10.0;
      final rpe = rs.set.rpeX10 != null ? rs.set.rpeX10! / 10.0 : 7.0;
      final rpeFactor = rpe >= 9
          ? 1.5
          : rpe >= 8
              ? 1.3
              : 1.0;
      final setLoad = intensity * rpeFactor * rs.setType.cnsFactor;

      final day =
          DateTime(completedAt.year, completedAt.month, completedAt.day);
      if (dailyLoads.containsKey(day)) {
        dailyLoads[day] = dailyLoads[day]! + setLoad;
      }

      final hours = asOf.difference(completedAt).inHours;
      if (hours >= 0 && hours <= _gaugeWindowHours) {
        gauge += _perSetBase * setLoad * exp(-hours * ln2 / _gaugeHalfLifeHours);
      }
    }

    final daily = [
      for (final e in dailyLoads.entries) DailyCnsLoad(e.key, e.value),
    ]..sort((a, b) => a.day.compareTo(b.day));

    final acute = daily
        .skip(max(0, daily.length - 7))
        .fold(0.0, (sum, d) => sum + d.load);
    final chronic =
        daily.fold(0.0, (sum, d) => sum + d.load) / max(1, daily.length ~/ 7);

    return CnsTrendsResult(
      daily: daily,
      currentLoad: gauge.clamp(0.0, 1.0),
      // Require a meaningful chronic base so week one doesn't scream deload.
      deloadSuggested: chronic > 1.0 && acute > 1.4 * chronic,
      acuteWeeklyLoad: acute,
      chronicWeeklyLoad: chronic,
    );
  }
}
