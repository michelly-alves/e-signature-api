import 'package:flutter/material.dart';
import 'dart:developer';
import '../data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  String? _token;
  String? get token => _token;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isAuthCheckComplete = false;
  bool get isAuthCheckComplete => _isAuthCheckComplete;

  AuthProvider() {
    log('AuthProvider: Inicializando...');
    _loadTokenFromPrefs();
  }

  Future<void> _loadTokenFromPrefs() async {
    log('AuthProvider: Carregando token do SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _isAuthenticated = _token != null;
    _isAuthCheckComplete = true;
    log('AuthProvider: Token carregado: ${_token != null}');
    notifyListeners();
  }

Future<bool> login(String email, String password) async {
  _isLoading = true;
  notifyListeners();

  final token = await _authRepository.signIn(email: email, password: password);
  final prefs = await SharedPreferences.getInstance();

  if (token != null) {
    _token = token;
    _isAuthenticated = true;
    await prefs.setString('jwt_token', token);
    log('AuthProvider: Token salvo no login: $_token');
  } else {
    _token = null;
    _isAuthenticated = false;
    await prefs.remove('jwt_token');
    log('AuthProvider: Falha no login, token removido');
  }

  _isLoading = false;
  notifyListeners();
  return _isAuthenticated;
}

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    log('AuthProvider: Logout realizado. Token removido.');
    notifyListeners();
  }
}
