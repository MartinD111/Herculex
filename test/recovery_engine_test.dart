import 'package:flutter_test/flutter_test.dart';
import 'package:herculex/data/local/database.dart';
import 'package:herculex/features/analytics/domain/cns_fatigue.dart';
import 'package:herculex/features/analytics/domain/muscle_recovery.dart';

// ── Factories for the generated data classes ────────────────────────────────
ExerciseCatalogData _ex(int id, String primaryMuscle, {int cns = 3}) =>
    ExerciseCatalogData(
      id: id,
      name: 'Exercise $id',
      primaryMuscle: primaryMuscle,
      equipment: 'Barbell',
      mechanics: 'compound',
      force: 'pull',
      plane: 'axial',
      defaultRestSeconds: 120,
      isCustom: false,
      category: 'strength',
      modality: 'barbell',
      cnsScore: cns,
      recoveryImpact: 3,
      loggingMetric: 'weight_reps',
      supportsWeightedBodyweight: false,
      isReviewed: true,
    );

WorkoutExerciseData _we(int id, int exerciseId) => WorkoutExerciseData(
      id: id,
      sessionId: 1,
      exerciseId: exerciseId,
      orderIndex: 0,
    );

SetEntryData _set(int id, int weId, DateTime completedAt, {int rpe = 8}) =>
    SetEntryData(
      id: id,
      workoutExerciseId: weId,
      setIndex: 0,
      weightKg: 100,
      reps: 5,
      rpeX10: rpe * 10,
      isWarmup: false,
      isCompleted: true,
      completedAt: completedAt,
      setType: 'standard',
    );

ExerciseMuscleData _m(int id, int exId, String muscle, String role,
        {double contribution = 1.0}) =>
    ExerciseMuscleData(
      id: id,
      exerciseId: exId,
      muscle: muscle,
      role: role,
      contribution: contribution,
    );

void main() {
  final asOf = DateTime(2026, 6, 8, 12);
  final oneHourAgo = asOf.subtract(const Duration(hours: 1));

  group('MuscleRecovery v2', () {
    test('aggregates primary, secondary and stabilizer involvement', () {
      // Deadlift-like: primary Hamstrings+Glutes, secondary Erectors(→Back).
      final catalog = [_ex(1, 'Hamstrings')];
      final muscles = [
        _m(1, 1, 'Hamstrings', 'primary'),
        _m(2, 1, 'Glutes', 'primary'),
        _m(3, 1, 'Erectors', 'secondary'),
      ];
      final result = MuscleRecovery.compute(
        sets: [_set(1, 1, oneHourAgo)],
        workoutExercises: [_we(1, 1)],
        catalog: catalog,
        exerciseMuscles: muscles,
        asOf: asOf,
      );
      final byGroup = {for (final r in result) r.muscle: r.score};

      // Glutes fold into the Hamstrings display group (primary weight).
      expect(byGroup['Hamstrings']!, greaterThan(0));
      // Erectors fold into Back at the lower secondary weight.
      expect(byGroup['Back']!, greaterThan(0));
      expect(byGroup['Back']!, lessThan(byGroup['Hamstrings']!));
      // Uninvolved groups stay fully recovered.
      expect(byGroup['Arms'], 0.0);
      expect(byGroup['Chest'], 0.0);
    });

    test('falls back to legacy primaryMuscle when no muscle rows exist', () {
      final result = MuscleRecovery.compute(
        sets: [_set(1, 1, oneHourAgo)],
        workoutExercises: [_we(1, 1)],
        catalog: [_ex(1, 'Chest')],
        exerciseMuscles: const [], // legacy seed, not yet enriched
        asOf: asOf,
      );
      final chest = result.firstWhere((r) => r.muscle == 'Chest').score;
      expect(chest, greaterThan(0));
    });

    test('advisories flag under-recovered muscles past the threshold', () {
      final hot = [const MuscleRecoveryResult('Back', 0.85)];
      final advisories = MuscleRecovery.advisories(hot);
      expect(advisories, hasLength(1));
      expect(advisories.first.muscle, 'Back');
    });
  });

  group('CnsFatigue', () {
    test('higher CNS-score work accrues more load than low-CNS work', () {
      sets(int weId) => [
            _set(1, weId, oneHourAgo),
            _set(2, weId, oneHourAgo),
            _set(3, weId, oneHourAgo),
          ];
      final heavy = CnsFatigue.compute(
        sets: sets(1),
        workoutExercises: [_we(1, 1)],
        catalog: [_ex(1, 'Quads', cns: 9)],
        asOf: asOf,
      );
      final light = CnsFatigue.compute(
        sets: sets(1),
        workoutExercises: [_we(1, 1)],
        catalog: [_ex(1, 'Biceps', cns: 2)],
        asOf: asOf,
      );
      expect(heavy.load, greaterThan(light.load));
      expect(heavy.readiness, lessThan(light.readiness));
      expect(heavy.readiness, inInclusiveRange(0.0, 1.0));
    });

    test('load decays toward zero outside the window', () {
      final old = CnsFatigue.compute(
        sets: [_set(1, 1, asOf.subtract(const Duration(hours: 200)))],
        workoutExercises: [_we(1, 1)],
        catalog: [_ex(1, 'Quads', cns: 9)],
        asOf: asOf,
      );
      expect(old.load, 0.0);
    });
  });
}
