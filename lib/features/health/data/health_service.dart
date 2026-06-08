import 'dart:math';
import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../data/local/database.dart';

class HealthService {
  final AppDatabase _db;
  final Clock _clock;

  HealthService(this._db, this._clock);

  Future<bool> requestPermissions(String platform) async {
    // Simulates authorization delay and returning true
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  Future<void> runDailySync() async {
    final todayStr = _formatDateIso(_clock.now());

    // Generate simulated daily biometric and activity details
    final random = Random();
    final steps = 8000.0 + random.nextInt(12000); // 8,000 - 20,000 steps
    final sleep = 6.0 + random.nextDouble() * 3.0; // 6.0 - 9.0 hours
    final kcal = 300.0 + random.nextInt(600); // 300 - 900 active kcal
    final hr = 55.0 + random.nextInt(15); // 55 - 70 resting HR

    await _db.transaction(() async {
      // Clear existing daily records to avoid duplicates on sync re-runs
      await (_db.delete(_db.healthSamples)..where((t) => t.dateIso.equals(todayStr))).go();

      await _db.into(_db.healthSamples).insert(
            HealthSamplesCompanion.insert(
              dateIso: todayStr,
              kind: 'steps',
              value: steps,
            ),
          );

      await _db.into(_db.healthSamples).insert(
            HealthSamplesCompanion.insert(
              dateIso: todayStr,
              kind: 'sleep_hours',
              value: sleep,
            ),
          );

      await _db.into(_db.healthSamples).insert(
            HealthSamplesCompanion.insert(
              dateIso: todayStr,
              kind: 'active_kcal',
              value: kcal,
            ),
          );

      await _db.into(_db.healthSamples).insert(
            HealthSamplesCompanion.insert(
              dateIso: todayStr,
              kind: 'resting_hr',
              value: hr,
            ),
          );
    });
  }

  Stream<List<HealthSampleData>> watchTodaySamples() {
    final todayStr = _formatDateIso(_clock.now());
    return (_db.select(_db.healthSamples)..where((t) => t.dateIso.equals(todayStr))).watch();
  }

  Future<double> getAverageSteps(int days) async {
    final cutoff = _clock.now().subtract(Duration(days: days));
    final samples = await (_db.select(_db.healthSamples)
          ..where((t) => t.kind.equals('steps') & t.dateIso.isBiggerOrEqualValue(_formatDateIso(cutoff))))
        .get();

    if (samples.isEmpty) return 10000.0; // standard baseline step count

    final sum = samples.fold<double>(0.0, (val, element) => val + element.value);
    return sum / samples.length;
  }

  String _formatDateIso(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
}
