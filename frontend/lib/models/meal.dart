/// Meal and daily summary data models.

class MealFood {
  final String id;
  final String foodName;
  final double confidence;
  final double portionGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  MealFood({
    required this.id,
    required this.foodName,
    required this.confidence,
    required this.portionGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
  });

  factory MealFood.fromJson(Map<String, dynamic> json) {
    return MealFood(
      id: json['id'] ?? '',
      foodName: json['food_name'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      portionGrams: (json['portion_grams'] as num?)?.toDouble() ?? 100.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'confidence': confidence,
        'portion_grams': portionGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };
}

class Meal {
  final String id;
  final String mealType;
  final DateTime timestamp;
  final String? notes;
  final double? score;
  final List<MealFood> foods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  Meal({
    required this.id,
    required this.mealType,
    required this.timestamp,
    this.notes,
    this.score,
    required this.foods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] ?? '',
      mealType: json['meal_type'] ?? 'snack',
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
      score: (json['score'] as num?)?.toDouble(),
      foods: (json['foods'] as List? ?? [])
          .map((f) => MealFood.fromJson(f))
          .toList(),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0,
    );
  }

  String get mealTypeDisplay {
    switch (mealType) {
      case 'breakfast':
        return '🌅 Breakfast';
      case 'lunch':
        return '☀️ Lunch';
      case 'dinner':
        return '🌙 Dinner';
      case 'snack':
        return '🍎 Snack';
      default:
        return mealType;
    }
  }
}

class DailySummary {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double waterMl;
  final int mealCount;
  final double calorieGoal;
  final double calorieProgress;

  DailySummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.waterMl,
    required this.mealCount,
    required this.calorieGoal,
    required this.calorieProgress,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date']),
      totalCalories: (json['total_calories'] as num).toDouble(),
      totalProtein: (json['total_protein'] as num).toDouble(),
      totalCarbs: (json['total_carbs'] as num).toDouble(),
      totalFat: (json['total_fat'] as num).toDouble(),
      waterMl: (json['water_ml'] as num).toDouble(),
      mealCount: json['meal_count'] as int,
      calorieGoal: (json['calorie_goal'] as num).toDouble(),
      calorieProgress: (json['calorie_progress'] as num).toDouble(),
    );
  }

  factory DailySummary.empty() {
    return DailySummary(
      date: DateTime.now(),
      totalCalories: 0,
      totalProtein: 0,
      totalCarbs: 0,
      totalFat: 0,
      waterMl: 0,
      mealCount: 0,
      calorieGoal: 2000,
      calorieProgress: 0,
    );
  }
}

class WeeklyProgress {
  final List<DailySummary> days;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int streak;

  WeeklyProgress({
    required this.days,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.streak,
  });

  factory WeeklyProgress.fromJson(Map<String, dynamic> json) {
    return WeeklyProgress(
      days: (json['days'] as List)
          .map((d) => DailySummary.fromJson(d))
          .toList(),
      avgCalories: (json['avg_calories'] as num).toDouble(),
      avgProtein: (json['avg_protein'] as num).toDouble(),
      avgCarbs: (json['avg_carbs'] as num).toDouble(),
      avgFat: (json['avg_fat'] as num).toDouble(),
      streak: json['streak'] as int,
    );
  }

  factory WeeklyProgress.empty() {
    return WeeklyProgress(
      days: [],
      avgCalories: 0,
      avgProtein: 0,
      avgCarbs: 0,
      avgFat: 0,
      streak: 0,
    );
  }
}
