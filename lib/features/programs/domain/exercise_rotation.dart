/// Exercise rotation — the accommodation law (V2 §12). A pool of variations
/// for a movement pattern rotates its active exercise every 1–4 weeks, e.g.
/// Close-Grip Bench → Floor Press → Paused OHP.
class ExerciseRotation {
  /// Which pool member (by order index) is active in program week [weekIndex]
  /// when the pool has [memberCount] members rotating every [rotateEveryWeeks].
  static int activeMemberIndex({
    required int weekIndex,
    required int memberCount,
    required int rotateEveryWeeks,
  }) {
    assert(memberCount > 0);
    final every = rotateEveryWeeks.clamp(1, 4);
    return (weekIndex ~/ every) % memberCount;
  }

  /// All (weekIndex → memberIndex) assignments for a program, useful for
  /// previewing the rotation in the builder UI.
  static List<int> assignments({
    required int weeks,
    required int memberCount,
    required int rotateEveryWeeks,
  }) {
    return [
      for (var w = 0; w < weeks; w++)
        activeMemberIndex(
          weekIndex: w,
          memberCount: memberCount,
          rotateEveryWeeks: rotateEveryWeeks,
        ),
    ];
  }
}
