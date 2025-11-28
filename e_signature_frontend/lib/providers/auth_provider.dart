import 'package:flutter/material.dart';
import 'dart:developer';
import '../data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  String? _token;
  String? get token => _token;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isAuthCheckComplete = false;
  bool get isAuthCheckComplete => _isAuthCheckComplete;

  AuthProvider() {
    _loadTokenFromPrefs();
  }

  Future<void> _loadTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');

    if (_token != null) {
      _user = await _authRepository.getCurrentUser();

      // Se falhar, invalida sessão
      if (_user == null) {
        await prefs.remove('jwt_token');
        _token = null;
        _isAuthenticated = false;
      } else {
        _isAuthenticated = true;
      }
    }

    _isAuthCheckComplete = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    final token = await _authRepository.signIn(
      email: email,
      password: password,
    );

    if (token != null) {
      await prefs.setString('jwt_token', token);

      _token = token;
      _isAuthenticated = true;

      // Buscar usuário
      _user = await _authRepository.getCurrentUser();
      if (_user == null) {
        // Token inválido, remove
        await prefs.remove('jwt_token');
        _token = null;
        _isAuthenticated = false;
      }
    } else {
      await prefs.remove('jwt_token');
      _token = null;
      _user = null;
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();

    return _isAuthenticated;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    _token = null;
    _user = null;
    _isAuthenticated = false;

    notifyListeners();
  }
}
