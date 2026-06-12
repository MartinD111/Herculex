import 'package:drift/drift.dart';

import '../../../data/local/database.dart';

class TemplatesRepository {
  final AppDatabase _db;
  TemplatesRepository(this._db);

  // ── Folders ────────────────────────────────────────────────────────────

  Stream<List<WorkoutFolderData>> watchFolders() =>
      (_db.select(_db.workoutFolders)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .watch();

  Future<WorkoutFolderData> createFolder({required String name, String emoji = '💪'}) async {
    final id = await _db.into(_db.workoutFolders).insert(
          WorkoutFoldersCompanion.insert(name: name, emoji: Value(emoji)),
        );
    return (_db.select(_db.workoutFolders)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> renameFolder(int id, {required String name, required String emoji}) =>
      (_db.update(_db.workoutFolders)..where((t) => t.id.equals(id)))
          .write(WorkoutFoldersCompanion(name: Value(name), emoji: Value(emoji)));

  Future<void> deleteFolder(int id) =>
      (_db.delete(_db.workoutFolders)..where((t) => t.id.equals(id))).go();

  // ── Templates ──────────────────────────────────────────────────────────

  /// All templates, optionally filtered by folder. Pass null to get unfiled ones,
  /// pass -1 to get all.
  Stream<List<WorkoutTemplateData>> watchTemplates({int? folderId}) {
    final q = _db.select(_db.workoutTemplates)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (folderId == null) {
      q.where((t) => t.folderId.isNull());
    } else if (folderId != -1) {
      q.where((t) => t.folderId.equals(folderId));
    }
    return q.watch();
  }

  Future<WorkoutTemplateData> createTemplate({
    required String name,
    String? notes,
    int? folderId,
  }) async {
    final id = await _db.into(_db.workoutTemplates).insert(
          WorkoutTemplatesCompanion.insert(
            name: name,
            notes: Value(notes),
            folderId: Value(folderId),
          ),
        );
    return (_db.select(_db.workoutTemplates)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateTemplate(int id, {String? name, String? notes, int? folderId, bool clearFolder = false}) =>
      (_db.update(_db.workoutTemplates)..where((t) => t.id.equals(id))).write(
        WorkoutTemplatesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          notes: notes != null ? Value(notes) : const Value.absent(),
          folderId: clearFolder ? const Value(null) : (folderId != null ? Value(folderId) : const Value.absent()),
        ),
      );

  Future<void> deleteTemplate(int id) =>
      (_db.delete(_db.workoutTemplates)..where((t) => t.id.equals(id))).go();

  Future<void> markUsed(int templateId) =>
      (_db.update(_db.workoutTemplates)..where((t) => t.id.equals(templateId)))
          .write(WorkoutTemplatesCompanion(lastUsedAt: Value(DateTime.now())));

  // ── Template exercises ─────────────────────────────────────────────────

  Stream<List<TemplateExerciseData>> watchTemplateExercises(int templateId) =>
      (_db.select(_db.templateExercises)
            ..where((t) => t.templateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Future<void> addExerciseToTemplate({
    required int templateId,
    required int exerciseId,
    int targetSets = 3,
    int? targetRepsMin,
    int? targetRepsMax,
    int? targetRestSeconds,
  }) async {
    final existing = await (_db.select(_db.templateExercises)
          ..where((t) => t.templateId.equals(templateId)))
        .get();
    await _db.into(_db.templateExercises).insert(
          TemplateExercisesCompanion.insert(
            templateId: templateId,
            exerciseId: exerciseId,
            orderIndex: existing.length,
            targetSets: Value(targetSets),
            targetRepsMin: Value(targetRepsMin),
            targetRepsMax: Value(targetRepsMax),
            targetRestSeconds: Value(targetRestSeconds),
          ),
        );
  }

  Future<void> removeExerciseFromTemplate(int templateExerciseId) =>
      (_db.delete(_db.templateExercises)
            ..where((t) => t.id.equals(templateExerciseId)))
          .go();

  Future<void> updateTemplateExercise(
    int id, {
    int? targetSets,
    int? targetRepsMin,
    int? targetRepsMax,
    int? targetRestSeconds,
  }) =>
      (_db.update(_db.templateExercises)..where((t) => t.id.equals(id))).write(
        TemplateExercisesCompanion(
          targetSets: targetSets != null ? Value(targetSets) : const Value.absent(),
          targetRepsMin: targetRepsMin != null ? Value(targetRepsMin) : const Value.absent(),
          targetRepsMax: targetRepsMax != null ? Value(targetRepsMax) : const Value.absent(),
          targetRestSeconds: targetRestSeconds != null ? Value(targetRestSeconds) : const Value.absent(),
        ),
      );

  /// Starts a live workout session pre-populated from a template.
  /// Returns the new session id.
  Future<int> startSessionFromTemplate(int templateId, AppDatabase db) async {
    final exercises = await (_db.select(_db.templateExercises)
          ..where((t) => t.templateId.equals(templateId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();

    return _db.transaction(() async {
      final sessionId = await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(startedAt: DateTime.now()),
          );
      for (final te in exercises) {
        await _db.into(_db.workoutExercises).insert(
              WorkoutExercisesCompanion.insert(
                sessionId: sessionId,
                exerciseId: te.exerciseId,
                orderIndex: te.orderIndex,
                targetRestSeconds: Value(te.targetRestSeconds),
              ),
            );
      }
      await markUsed(templateId);
      return sessionId;
    });
  }
}
