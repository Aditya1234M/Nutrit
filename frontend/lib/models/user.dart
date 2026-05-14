/// User and profile data models.

class User {
  final String id;
  final String name;
  final String email;
  final String subscriptionTier;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.subscriptionTier = 'free',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      subscriptionTier: json['subscription_tier'] ?? 'free',
    );
  }
}

class UserProfile {
  final int? age;
  final double? weight;
  final double? height;
  final String? gender;
  final String? activityLevel;
  final String? goalType;

  UserProfile({
    this.age,
    this.weight,
    this.height,
    this.gender,
    this.activityLevel,
    this.goalType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      age: json['age'],
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      gender: json['gender'],
      activityLevel: json['activity_level'],
      goalType: json['goal_type'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (age != null) map['age'] = age;
    if (weight != null) map['weight'] = weight;
    if (height != null) map['height'] = height;
    if (gender != null) map['gender'] = gender;
    if (activityLevel != null) map['activity_level'] = activityLevel;
    if (goalType != null) map['goal_type'] = goalType;
    return map;
  }
}

class NutritionTargets {
  final double dailyCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double waterMl;

  NutritionTargets({
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
  });

  factory NutritionTargets.fromJson(Map<String, dynamic> json) {
    return NutritionTargets(
      dailyCalories: (json['daily_calories'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num).toDouble(),
      waterMl: (json['water_ml'] as num).toDouble(),
    );
  }

  /// Default targets when profile isn't set up yet.
  factory NutritionTargets.defaults() {
    return NutritionTargets(
      dailyCalories: 2000,
      proteinG: 75,
      carbsG: 250,
      fatG: 65,
      fiberG: 30,
      waterMl: 2500,
    );
  }
}
