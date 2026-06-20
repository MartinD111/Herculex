import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database.dart';
import '../features/profile/data/local_profile_repository.dart';
import '../features/profile/domain/profile.dart';

import '../features/gyms/data/gyms_repository.dart';
import '../features/measurements/data/measurements_repository.dart';
import '../features/workouts/data/accessories_repository.dart';
import '../features/workouts/data/exercise_progressions_repository.dart';
import '../data/sync/sync_engine.dart';

export '../core/clock.dart' show clockProvider;

/// Overridden in main() once SharedPreferences has been initialised.
final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = SyncEngine(db);
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncEngineProvider).statusStream;
});

final localProfileRepositoryProvider = Provider<LocalProfileRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = LocalProfileRepository(prefs);
  ref.onDispose(repo.dispose);
  return repo;
});

final profileProvider = StreamProvider<Profile?>((ref) {
  final repo = ref.watch(localProfileRepositoryProvider);
  return repo.watch();
});

/// Single AppDatabase instance for the lifetime of the app.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final gymsRepositoryProvider = Provider<GymsRepository>((ref) {
  return GymsRepository(ref.watch(appDatabaseProvider));
});

final accessoriesRepositoryProvider = Provider<AccessoriesRepository>((ref) {
  return AccessoriesRepository(ref.watch(appDatabaseProvider));
});

final measurementsRepositoryProvider = Provider<MeasurementsRepository>((ref) {
  return MeasurementsRepository(ref.watch(appDatabaseProvider));
});

final exerciseProgressionsRepositoryProvider =
    Provider<ExerciseProgressionsRepository>((ref) {
  return ExerciseProgressionsRepository(ref.watch(appDatabaseProvider));
});
