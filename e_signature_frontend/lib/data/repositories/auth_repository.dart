import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer';

class AuthRepository {
  final String _baseUrl = "http://localhost:8080/api";

  Future<String?> signIn({
  required String email,
  required String password,
}) async {
  final url = Uri.parse('$_baseUrl/auth/login');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final token = data['token'];
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      return token; 
    }
  }

  return null;
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
Future<bool> verifyFace(String imageBase64, String nationalId) async {
    final url = Uri.parse('$_baseUrl/signers/$nationalId/facial-verify');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'live_image_base64': imageBase64}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['match'] ?? false;
      } else {
        log('Falha na verificação facial: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      log('Erro na chamada da API de verificação facial: $e');
      return false;
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    final url = Uri.parse('$_baseUrl/users'); 
    try {
        final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        log('Erro no cadastro: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      log('Erro na chamada da API de criação de usuário: $e');
      return false;
    }
  }
}

