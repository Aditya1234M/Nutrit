/// Food prediction result from ML model inference.

class FoodPrediction {
  final String foodName;
  final double confidence;
  final String headSource; // "food101" or "indian"
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;

  FoodPrediction({
    required this.foodName,
    required this.confidence,
    required this.headSource,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
  });

  /// Human-readable display name (capitalize, replace underscores).
  String get displayName {
    return foodName
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Confidence as a percentage string.
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  factory FoodPrediction.fromJson(Map<String, dynamic> json) {
    return FoodPrediction(
      foodName: json['food_name'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      headSource: json['head_source'] ?? 'food101',
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble(),
      proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble(),
      carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble(),
      fatPer100g: (json['fat_per_100g'] as num?)?.toDouble(),
      fiberPer100g: (json['fiber_per_100g'] as num?)?.toDouble(),
    );
  }
}
