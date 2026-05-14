/// Authentication state management.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Try to restore session from saved token on app start.
  Future<bool> tryAutoLogin() async {
    await ApiService.init();
    if (!ApiService.isAuthenticated) return false;

    try {
      final data = await ApiService.get('/api/auth/me');
      _currentUser = User.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      // Token expired or invalid — clear it
      await ApiService.clearToken();
      return false;
    }
  }

  /// Register a new account.
  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.post('/api/auth/register', {
        'name': name,
        'email': email,
        'password': password,
      });

      await ApiService.setToken(data['access_token']);
      _currentUser = User(
        id: data['user_id'],
        name: data['name'],
        email: data['email'],
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection failed. Is the backend running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email and password.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      await ApiService.setToken(data['access_token']);
      _currentUser = User(
        id: data['user_id'],
        name: data['name'],
        email: data['email'],
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection failed. Is the backend running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    await ApiService.clearToken();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
