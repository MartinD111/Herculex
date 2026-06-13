class DailyTotals {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;
  final double potassiumMg;
  final double cholesterolMg;

  const DailyTotals({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.cholesterolMg = 0,
  });

  static const empty = DailyTotals();

  bool get hasMicros => sodiumMg > 0 || potassiumMg > 0 || cholesterolMg > 0;

  DailyTotals plus({
    double kcal = 0,
    double proteinG = 0,
    double carbsG = 0,
    double fatG = 0,
    double fiberG = 0,
    double sodiumMg = 0,
    double potassiumMg = 0,
    double cholesterolMg = 0,
  }) =>
      DailyTotals(
        kcal: this.kcal + kcal,
        proteinG: this.proteinG + proteinG,
        carbsG: this.carbsG + carbsG,
        fatG: this.fatG + fatG,
        fiberG: this.fiberG + fiberG,
        sodiumMg: this.sodiumMg + sodiumMg,
        potassiumMg: this.potassiumMg + potassiumMg,
        cholesterolMg: this.cholesterolMg + cholesterolMg,
      );
}
