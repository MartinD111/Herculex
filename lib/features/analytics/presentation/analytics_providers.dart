import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/analytics_repository.dart';
import '../domain/muscle_recovery.dart';
import '../domain/balance_analyzer.dart';
import '../domain/biometric_correlations.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});

final weeklyTonnageProvider = FutureProvider<List<WeeklyTonnage>>((ref) {
  return ref.watch(analyticsRepositoryProvider).weeklyTonnage();
});

final topOneRmsProvider = FutureProvider<List<OneRmProjection>>((ref) {
  return ref.watch(analyticsRepositoryProvider).topOneRms();
});

final muscleRecoveryProvider = FutureProvider<List<MuscleRecoveryResult>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final sets = await db.select(db.setEntries).get();
  final exercises = await db.select(db.workoutExercises).get();
  final catalog = await db.select(db.exerciseCatalog).get();
  
  return MuscleRecovery.compute(
    sets: sets,
    workoutExercises: exercises,
    catalog: catalog,
    asOf: DateTime.now(),
  );
});

final pushPullBalanceProvider = FutureProvider<BalanceResult>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final sets = await db.select(db.setEntries).get();
  final exercises = await db.select(db.workoutExercises).get();
  final catalog = await db.select(db.exerciseCatalog).get();
  
  return BalanceAnalyzer.summary(
    sets: sets,
    workoutExercises: exercises,
    catalog: catalog,
  );
});

final sleepVsRpeProvider = FutureProvider<BiometricCorrelationResult>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final healthSamples = await db.select(db.healthSamples).get();
  final sets = await db.select(db.setEntries).get();
  final exercises = await db.select(db.workoutExercises).get();
  final sessions = await db.select(db.workoutSessions).get();
  
  return BiometricCorrelations.sleepVsRpe(
    healthSamples: healthSamples,
    sets: sets,
    workoutExercises: exercises,
    sessions: sessions,
  );
});

final hrVsTonnageProvider = FutureProvider<BiometricCorrelationResult>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final healthSamples = await db.select(db.healthSamples).get();
  final sets = await db.select(db.setEntries).get();
  final exercises = await db.select(db.workoutExercises).get();
  final sessions = await db.select(db.workoutSessions).get();
  
  return BiometricCorrelations.restingHrVsTonnage(
    healthSamples: healthSamples,
    sets: sets,
    workoutExercises: exercises,
    sessions: sessions,
  );
});

