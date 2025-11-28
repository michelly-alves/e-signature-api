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
    final uri = Uri.parse("$_baseUrl/auth/login");

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode != 200) {
      log("Login falhou: ${response.body}");
      return null;
    }

    // Agora pega do JSON
    final data = jsonDecode(response.body);
    final token = data["token"];

    if (token == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("jwt_token", token);

    return token;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");

    if (token == null) return null;

    final uri = Uri.parse("$_baseUrl/users/me");

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    log("Erro ao obter usuário atual: ${response.statusCode} ${response.body}");
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

  Future<bool> verifyFace(String imageBase64, String signerId) async {
    final url = Uri.parse('$_baseUrl/signers/$signerId/facial-verify');

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
      log('Erro na chamada da API: $e');
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

      return response.statusCode == 201;
    } catch (e) {
      log('Erro ao criar usuário: $e');
      return false;
    }
  }
}
