import 'package:drift/drift.dart';

import '../../../data/local/database.dart';

class CycleRepository {
  final AppDatabase _db;

  CycleRepository(this._db);

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<CycleSettingData?> getSettings() {
    return (_db.select(_db.cycleSettings)..limit(1)).getSingleOrNull();
  }

  Future<void> saveSettings({
    required int avgCycleDays,
    required int avgPeriodDays,
    required DateTime lastPeriodStart,
  }) async {
    await _db.into(_db.cycleSettings).insertOnConflictUpdate(
          CycleSettingsCompanion.insert(
            id: const Value(1),
            avgCycleDays: Value(avgCycleDays),
            avgPeriodDays: Value(avgPeriodDays),
            lastPeriodStart: lastPeriodStart,
          ),
        );
  }

  // ── Logs & Overrides ─────────────────────────────────────────────────────

  Future<void> logManualOverride({
    required DateTime date,
    required String phase,
    required int intensity,
  }) async {
    final dateStr = _formatDateIso(date);
    await _db.transaction(() async {
      await (_db.delete(_db.cycleLogs)..where((t) => t.dateIso.equals(dateStr))).go();
      await _db.into(_db.cycleLogs).insert(
            CycleLogsCompanion.insert(
              dateIso: dateStr,
              phase: phase,
              intensity: Value(intensity),
              manualOverride: const Value(true),
            ),
          );
    });
  }

  Future<CycleLogData?> getManualOverride(DateTime date) {
    final dateStr = _formatDateIso(date);
    return (_db.select(_db.cycleLogs)..where((t) => t.dateIso.equals(dateStr))).getSingleOrNull();
  }

  // ── Prediction & Adjustments ─────────────────────────────────────────────

  Future<String> predictPhaseFor(DateTime date) async {
    // 1. Check if there is a manual override log for today
    final override = await getManualOverride(date);
    if (override != null) return override.phase;

    // 2. Fallback to predictor logic using cycle settings
    final settings = await getSettings();
    if (settings == null) return 'follicular'; // Standard default middle phase

    final start = settings.lastPeriodStart;
    final diffDays = date.difference(start).inDays;
    if (diffDays < 0) return 'follicular';

    final cycleDays = settings.avgCycleDays > 0 ? settings.avgCycleDays : 28;
    final dayOfCycle = diffDays % cycleDays;

    final periodDays = settings.avgPeriodDays > 0 ? settings.avgPeriodDays : 5;

    if (dayOfCycle < periodDays) {
      return 'menstrual';
    } else if (dayOfCycle < 12) {
      return 'follicular';
    } else if (dayOfCycle < 16) {
      return 'ovulatory';
    } else {
      return 'luteal';
    }
  }

  Future<double> getCycleMultiplierFor(DateTime date) async {
    final phase = await predictPhaseFor(date);
    switch (phase) {
      case 'menstrual':
        return 0.8; // -20% intensity / volume drop
      case 'follicular':
        return 1.1; // +10% energy boost
      case 'ovulatory':
        return 1.0; // normal
      case 'luteal':
        return 0.85; // -15% energy dip
      default:
        return 1.0;
    }
  }

  String _formatDateIso(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
}
