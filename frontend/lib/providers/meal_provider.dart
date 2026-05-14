/// Meal state management — logging, listing, daily/weekly data.

import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/api_service.dart';

class MealProvider extends ChangeNotifier {
  List<Meal> _todaysMeals = [];
  DailySummary _dailySummary = DailySummary.empty();
  WeeklyProgress _weeklyProgress = WeeklyProgress.empty();
  bool _isLoading = false;
  String? _error;

  List<Meal> get todaysMeals => _todaysMeals;
  DailySummary get dailySummary => _dailySummary;
  WeeklyProgress get weeklyProgress => _weeklyProgress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load today's meals from backend.
  Future<void> loadTodaysMeals() async {
    try {
      final data = await ApiService.get('/api/meals/today');
      final list = data['data'] as List? ?? [];
      _todaysMeals = list.map((m) => Meal.fromJson(m)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load meals';
      notifyListeners();
    }
  }

  /// Load today's daily summary.
  Future<void> loadDailySummary() async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final data = await ApiService.get('/api/users/daily-summary/$dateStr');
      _dailySummary = DailySummary.fromJson(data);
      notifyListeners();
    } catch (e) {
      // Keep empty summary on error
      notifyListeners();
    }
  }

  /// Load weekly progress.
  Future<void> loadWeeklyProgress() async {
    try {
      final data = await ApiService.get('/api/users/progress');
      _weeklyProgress = WeeklyProgress.fromJson(data);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load progress';
      notifyListeners();
    }
  }

  /// Log a new meal with food items.
  Future<Meal?> logMeal({
    required String mealType,
    required List<MealFood> foods,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.post('/api/meals/log', {
        'meal_type': mealType,
        'foods': foods.map((f) => f.toJson()).toList(),
        'notes': notes,
      });

      final meal = Meal.fromJson(data);
      _todaysMeals.insert(0, meal);

      _isLoading = false;
      notifyListeners();

      // Refresh daily summary in background
      loadDailySummary();

      return meal;
    } catch (e) {
      _error = 'Failed to log meal';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Delete a meal.
  Future<bool> deleteMeal(String mealId) async {
    try {
      await ApiService.delete('/api/meals/$mealId');
      _todaysMeals.removeWhere((m) => m.id == mealId);
      notifyListeners();
      loadDailySummary();
      return true;
    } catch (e) {
      _error = 'Failed to delete meal';
      notifyListeners();
      return false;
    }
  }

  /// Load all data for the home screen.
  Future<void> refreshAll() async {
    await Future.wait([
      loadTodaysMeals(),
      loadDailySummary(),
    ]);
  }
}
