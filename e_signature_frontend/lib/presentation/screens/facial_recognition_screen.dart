// lib/presentation/screens/facial_recognition_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/auth.dart';
import '../../theme/app_colors.dart';

class FacialRecognitionScreen extends StatefulWidget {
  final String userId; // O ID do usuário para verificação

  const FacialRecognitionScreen({super.key, required this.userId});

  @override
  State<FacialRecognitionScreen> createState() => _FacialRecognitionScreenState();
}

class _FacialRecognitionScreenState extends State<FacialRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = false;
  String? _message;
  bool? _verificationSuccess;

  Future<void> _captureAndVerify() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _verificationSuccess = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        final Uint8List imageBytes = await photo.readAsBytes();
        final String base64Image = base64Encode(imageBytes);

        final bool success = await _authRepository.verifyFace(base64Image, widget.userId);
        
        setState(() {
          _verificationSuccess = success;
          _message = success ? "Verificação realizada com sucesso!" : "Verificação falhou!";
        });
      }
    } catch (e) {
      setState(() {
        _message = "Ocorreu um erro. Tente novamente.";
        _verificationSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5F0F4),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _verificationSuccess == null
                ? _buildInitialUI()
                : _buildResultUI(),
      ),
    );
  }

  Widget _buildInitialUI() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Reconhecimento Facial",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Image.asset('assets/images/reconhecimento facial.png', height: 150),
          const SizedBox(height: 24),
          const Text(
            "Para maior segurança, vamos fazer um reconhecimento facial.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _captureAndVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              "Iniciar Reconhecimento Facial",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultUI() {
    return Container(
       padding: const EdgeInsets.all(32.0),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _message ?? "",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _verificationSuccess! ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Image.asset(
            _verificationSuccess! ? 'assets/images/cadeado_ok.png' : 'assets/images/upload.png', // Substitua 'falha.png' pela sua imagem de falha
            height: 120,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              if (_verificationSuccess!) {
                // Navegar para a próxima tela, ex: home
              } else {
                // Voltar para a tentativa
                setState(() {
                  _verificationSuccess = null;
                });
              }
            },
             style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: Text(
              _verificationSuccess! ? "Prosseguir" : "Tentar Novamente",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}