import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final String _baseUrl = 'http://127.0.0.1:8080';

  Future<List<Document>> getDocuments({required String? token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Token JWT não encontrado.');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/documents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Document.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar os documentos. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar documentos: $e');
      throw Exception('Erro ao buscar documentos.');
    }
  }

  Future<bool> createDocumentWithFiles({
  required int companyId,
  required int statusId,
  required String documentFileName,
  required Uint8List documentFileBytes,
  required String signerFullName,
  required String signerPhoneNumber,
  required String signerEmail,
  required String signerNationalId,
  required String photoIdFileName,
  required Uint8List photoIdFileBytes,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      throw Exception('Token JWT não encontrado.');
    }

    final dio = Dio();

    final formData = FormData.fromMap({
      'company_id': companyId,
      'status_id': statusId,
      'signer_full_name': signerFullName,
      'signer_phone_number': signerPhoneNumber,
      'signer_email': signerEmail,
      'signer_national_id': signerNationalId,
      'document_file': MultipartFile.fromBytes(
        documentFileBytes,
        filename: documentFileName,
      ),
      'signer_photo_id_file': MultipartFile.fromBytes(
        photoIdFileBytes,
        filename: photoIdFileName,
      ),
    });

    final response = await dio.post(
      'http://127.0.0.1:8080/documents',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return response.statusCode == 201;
  } on DioException catch (e) {
    print('Erro ao criar documento: ${e.response?.data ?? e.message}');
    return false;
  } catch (e) {
    print('Erro inesperado: $e');
    return false;
  }
}
}
