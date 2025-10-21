import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AuthRepository {
  final String _baseUrl = "http://localhost:8080/api"; 

  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
    String? telegramId,
    String? facialBiometrics,
  }) async {
    final url = Uri.parse('$_baseUrl/users');
    
    try {
      final body = json.encode({
        'user': {
          'username': username,
          'email': email,
          'password': password,
          'telegram_id': telegramId,
          'facial_biometrics': facialBiometrics,
        }
      });

      log('Enviando para Cadastro: $body');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      log('Resposta do Cadastro: ${response.statusCode}');

      return response.statusCode == 201;
    } catch (e) {
      log('Erro no cadastro: $e');
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    
    try {
      final body = json.encode({
        'email': email,
        'password': password,
      });

      log('Enviando para Login: $body');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      log('Resposta do Login: ${response.statusCode}');
      log('Corpo da Resposta do Login: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['token']; 
      } else {
        return null;
      }
    } catch (e) {
      log('Erro no login: $e');
      return null;
    }
  }

  Future<bool> verifyFace(String imageBase64, String userId) async {
    final url = Uri.parse('$_baseUrl/users/$userId/facial-verify');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image_base64': imageBase64}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['match'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      log('Error verifying face: $e');
      return false;
    }
  }
  Future<bool> createUser(Map<String, dynamic> userData) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createUser}');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Erro no cadastro: ${response.statusCode} - ${response.body}');
      return false;
    }
  }
}