/// User profile state management.

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  NutritionTargets _targets = NutritionTargets.defaults();
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  NutritionTargets get targets => _targets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null && (_profile!.weight ?? 0) > 0;

  /// Load user profile from backend.
  Future<void> loadProfile() async {
    try {
      final data = await ApiService.get('/api/users/profile');
      _profile = UserProfile.fromJson(data);
      notifyListeners();
    } catch (e) {
      // Profile might not exist yet — that's fine
    }
  }

  /// Load personalized nutrition targets.
  Future<void> loadTargets() async {
    try {
      final data = await ApiService.get('/api/users/targets');
      _targets = NutritionTargets.fromJson(data);
      notifyListeners();
    } catch (e) {
      _targets = NutritionTargets.defaults();
      notifyListeners();
    }
  }

  /// Update user profile.
  Future<bool> updateProfile({
    int? age,
    double? weight,
    double? height,
    String? gender,
    String? activityLevel,
    String? goalType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (age != null) body['age'] = age;
      if (weight != null) body['weight'] = weight;
      if (height != null) body['height'] = height;
      if (gender != null) body['gender'] = gender;
      if (activityLevel != null) body['activity_level'] = activityLevel;
      if (goalType != null) body['goal_type'] = goalType;

      final data = await ApiService.put('/api/users/profile', body);
      _profile = UserProfile.fromJson(data);

      // Refresh targets since profile changed
      await loadTargets();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load both profile and targets.
  Future<void> loadAll() async {
    await Future.wait([
      loadProfile(),
      loadTargets(),
    ]);
  }
}
