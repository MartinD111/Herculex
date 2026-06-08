/// Normalized food shape returned by the OpenFoodFacts client.
/// Pure DTO — no Drift dependency so it's safe to share with UI directly.
class RemoteFood {
  final String? barcode;
  final String name;
  final String? brand;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? fiberPer100g;
  final double? servingGrams;
  final String? servingLabel;
  final String? imageUrl;

  const RemoteFood({
    this.barcode,
    required this.name,
    this.brand,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g,
    this.servingGrams,
    this.servingLabel,
    this.imageUrl,
  });
}
