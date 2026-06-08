import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/cycle_repository.dart';
import '../../../data/local/database.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final clock = ref.watch(clockProvider);
  return CycleRepository(db, clock);
});

final cycleSettingsProvider = FutureProvider<CycleSettingData?>((ref) {
  final repo = ref.watch(cycleRepositoryProvider);
  return repo.getSettings();
});

final predictedPhaseProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(cycleRepositoryProvider);
  // Re-run whenever settings change
  ref.watch(cycleSettingsProvider);
  return repo.predictPhaseFor(DateTime.now());
});

final cycleMultiplierProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(cycleRepositoryProvider);
  // Re-run whenever settings change
  ref.watch(cycleSettingsProvider);
  return repo.getCycleMultiplierFor(DateTime.now());
});
