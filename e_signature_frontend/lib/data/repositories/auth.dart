import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthRepository {
  final String _baseUrl = "http://localhost:8000/api"; 

  Future<bool> verifyFace(String imageBase64, String userId) async {
    final url = Uri.parse('$_baseUrl/user/facial-verify');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'image': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}