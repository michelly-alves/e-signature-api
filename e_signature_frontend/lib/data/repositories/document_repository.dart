import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentRepository {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://127.0.0.1:8080';

  Future<bool> createDocumentWithFile({
    required int companyId, 
    required int statusId, 
    required String fileName,
    required Uint8List fileBytes,

    required String signerFullName,
    required String signerPhoneNumber,
    required String signerEmail,
    required String signerNationalId, 
    String? photoIdUrl, 
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
     /* if (token == null) {
        print('Erro: Token JWT não encontrado.');
        return false;
      }*/

      final formData = FormData.fromMap({
        'company_id': companyId,
        'status_id': statusId,
        'file_name': fileName, 

        'signer_full_name': signerFullName,
        'signer_phone_number': signerPhoneNumber,
        'signer_email': signerEmail,
        'signer_national_id': signerNationalId,
        if (photoIdUrl != null) 'photo_id_url': photoIdUrl,

        'document_file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl/documents',
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
