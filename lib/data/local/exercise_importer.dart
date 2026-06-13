import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'database.dart';
import 'exercise_biomechanics.dart';
import 'seed_data.dart';

/// Imports the enriched exercise catalog (`assets/data/exercises.json`) into the
/// database. Idempotent: upserts by [ExerciseCatalog.name], preserving row ids
/// (so logged sets keep their FK) and replacing each exercise's muscle/alias
/// rows. Safe to re-run on every app upgrade.
class ExerciseImporter {
  static const assetPath = 'assets/data/exercises.json';

  /// Loads the bundled asset and imports it. Falls back to the legacy seed list
  /// when the asset bundle is unavailable (e.g. unit tests with an in-memory DB).
  static Future<void> runFromAsset(AppDatabase db) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      await runFromJson(db, raw);
    } catch (_) {
      await _seedFallback(db);
    }
  }

  /// Imports exercises from a JSON array string. Used directly by tests.
  static Future<void> runFromJson(AppDatabase db, String jsonStr) async {
    final list = (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
    await db.transaction(() async {
      for (final e in list) {
        await _upsert(db, e);
      }
    });
  }

  static Future<void> _upsert(AppDatabase db, Map<String, dynamic> e) async {
    final name = (e['name'] as String).trim();
    final pattern = e['movementPattern'] as String?;
    final category = (e['category'] as String?) ?? 'strength';
    final primaryMuscle = (e['primaryMuscle'] as String?) ?? 'Core';
    final aka = (e['aka'] as List?)?.cast<String>() ?? const [];
    final attachments = (e['attachments'] as List?)?.cast<String>();

    final companion = ExerciseCatalogCompanion(
      name: Value(name),
      primaryMuscle: Value(primaryMuscle),
      equipment: Value((e['equipment'] as String?) ?? 'Other'),
      mechanics: Value(ExerciseBiomechanics.mechanics(pattern, category)),
      force: Value(ExerciseBiomechanics.force(pattern, primaryMuscle)),
      plane: Value(ExerciseBiomechanics.plane(pattern)),
      defaultRestSeconds: Value((e['defaultRestSeconds'] as int?) ?? 120),
      aka: Value(aka.isEmpty ? null : aka.join(', ')),
      category: Value(category),
      movementPattern: Value(pattern),
      movementPatternRaw: Value(e['movementPatternRaw'] as String?),
      modality: Value((e['modality'] as String?) ?? 'barbell'),
      cnsScore: Value((e['cnsScore'] as int?) ?? 3),
      recoveryImpact: Value((e['recoveryImpact'] as int?) ?? 3),
      loggingMetric: Value((e['loggingMetric'] as String?) ?? 'weight_reps'),
      supportsWeightedBodyweight:
          Value((e['supportsWeightedBodyweight'] as bool?) ?? false),
      attachments:
          Value(attachments == null ? null : jsonEncode(attachments)),
      isReviewed: Value((e['derived'] as bool?) == true ? false : true),
      movementFamily: Value(_movementFamily(name, pattern, primaryMuscle)),
    );

    final existing = await (db.select(db.exerciseCatalog)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();

    final int id;
    if (existing == null) {
      id = await db.into(db.exerciseCatalog).insert(companion);
    } else {
      id = existing.id;
      // Preserve id + isCustom; refresh everything else.
      await (db.update(db.exerciseCatalog)..where((t) => t.id.equals(id)))
          .write(companion);
      await (db.delete(db.exerciseMuscles)
            ..where((t) => t.exerciseId.equals(id)))
          .go();
      await (db.delete(db.exerciseAliases)
            ..where((t) => t.exerciseId.equals(id)))
          .go();
    }

    await _writeMuscles(db, id, e['primaryMuscles'], 'primary');
    await _writeMuscles(db, id, e['secondaryMuscles'], 'secondary');
    await _writeMuscles(db, id, e['stabilizers'], 'stabilizer');

    for (final alias in aka) {
      await db.into(db.exerciseAliases).insert(
            ExerciseAliasesCompanion.insert(exerciseId: id, alias: alias),
          );
    }
  }

  /// Equipment tokens stripped from a name to find its base movement. Mirrors
  /// the equipment vocabulary in `tool/build_exercises.py`. Order matters:
  /// multi-word tokens are tried before their substrings (handled by sorting
  /// on length in [_movementFamily]).
  static const _equipmentTokens = <String>[
    'swiss bar', 'safety bar', 'axle bar', 'cambered bar', 'duffalo bar',
    'trap bar', 'hex bar', 'ez bar', 'ez-bar', 'landmine', 'meadows',
    'smith machine', 'smith', 'machine', 'cable', 'band-assisted', 'banded',
    'band', 'kettlebell', 'dumbbell', 'barbell', 'plate-loaded', 'plate',
    'iso-lateral', 'hammer', 'pendulum', 'v-squat', 'belt squat', 'sled',
    'yoke', 'rings', 'ring', 'trx', 'suspension', 'neck harness',
  ];

  /// Derives the movement-family key: the base movement name (equipment words
  /// removed, bench→press normalized) scoped by movement pattern + coarse
  /// muscle. Real modifiers (incline/decline/close-grip/…) survive, so
  /// "Incline Press" and "Bench Press" remain distinct families while their
  /// equipment variants collapse together. Returns null when there's no usable
  /// pattern, so such rows stay ungrouped.
  static String? _movementFamily(
      String name, String? pattern, String primaryMuscle) {
    if (pattern == null || pattern.isEmpty) return null;
    var n = ' ${name.toLowerCase()} ';
    for (final t in _equipmentTokens) {
      n = n.replaceAll(' $t ', ' ');
    }
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Press/bench synonyms collapse onto "press".
    n = n.replaceAll('bench press', 'press').replaceAll('bench', 'press');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (n.isEmpty) return null;
    return '$n|$pattern|$primaryMuscle';
  }

  static Future<void> _writeMuscles(
      AppDatabase db, int id, dynamic raw, String role) async {
    final muscles = (raw as List?)?.cast<String>() ?? const [];
    for (final m in muscles) {
      await db.into(db.exerciseMuscles).insertOnConflictUpdate(
            ExerciseMusclesCompanion.insert(
              exerciseId: id,
              muscle: m,
              role: role,
            ),
          );
    }
  }

  /// Used when the JSON asset is unavailable; seeds the legacy starter catalog
  /// enriched with safe defaults so the app remains usable.
  static Future<void> _seedFallback(AppDatabase db) async {
    final already = await db.select(db.exerciseCatalog).get();
    if (already.isNotEmpty) return;
    await db.batch((b) {
      b.insertAll(
        db.exerciseCatalog,
        kSeedExercises.map(
          (e) => ExerciseCatalogCompanion.insert(
            name: e.name,
            primaryMuscle: e.primaryMuscle,
            equipment: e.equipment,
            mechanics: e.mechanics,
            force: e.force,
            plane: e.plane,
            defaultRestSeconds: Value(e.defaultRestSeconds),
          ),
        ),
      );
    });
  }
}
