class DailyTotals {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  const DailyTotals({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
  });

  static const empty = DailyTotals();

  DailyTotals plus({
    double kcal = 0,
    double proteinG = 0,
    double carbsG = 0,
    double fatG = 0,
    double fiberG = 0,
  }) =>
      DailyTotals(
        kcal: this.kcal + kcal,
        proteinG: this.proteinG + proteinG,
        carbsG: this.carbsG + carbsG,
        fatG: this.fatG + fatG,
        fiberG: this.fiberG + fiberG,
      );
}
