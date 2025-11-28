import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';

enum ScreenState { initial, camera, loading, result }

class FacialRecognitionScreen extends StatefulWidget {
  final String userId; 

  const FacialRecognitionScreen({super.key, required this.userId}); 

  @override
  State<FacialRecognitionScreen> createState() => _FacialRecognitionScreenState();
}

class _FacialRecognitionScreenState extends State<FacialRecognitionScreen> {
  final AuthRepository _authRepository = AuthRepository();

  ScreenState _screenState = ScreenState.initial;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  String? _message;
  bool? _verificationSuccess;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cameraController?.dispose(); 
    super.dispose();
  }

  Future<void> _initializeAndShowCamera() async {
    if (!kIsWeb) {
    }

    _cameras = await availableCameras();
    final frontCamera = _cameras?.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    if (frontCamera == null) {
      setState(() {
         _message = "Nenhuma câmera encontrada.";
         _verificationSuccess = false;
         _screenState = ScreenState.result;
      });
      return;
    }

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _screenState = ScreenState.camera;
      });
    } catch (e) {
      print("Erro ao inicializar a câmera: $e");
       setState(() {
         _message = "Erro ao acessar a câmera.";
         _verificationSuccess = false;
         _screenState = ScreenState.result;
      });
    }
  }

  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() { _screenState = ScreenState.loading; });

    try {
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      final bool success = await _authRepository.verifyFace(base64Image, widget.userId); 

      setState(() {
        _verificationSuccess = success;
        _message = success ? "Verificação realizada com sucesso!" : "Verificação falhou!";
        _screenState = ScreenState.result;
      });
    } catch (e) {
      setState(() {
        _message = "Ocorreu um erro ao capturar a foto. Tente novamente.";
        _verificationSuccess = false;
        _screenState = ScreenState.result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildUIForState(),
        ),
      ),
    );
  }

  Widget _buildUIForState() {
    switch (_screenState) {
      case ScreenState.initial:
        return _buildInitialUI();
      case ScreenState.camera:
        return _buildCameraUI();
      case ScreenState.loading:
        return const CircularProgressIndicator(color: AppColors.primaryButton);
      case ScreenState.result:
        return _buildResultUI();
    }
  }

  Widget _buildInitialUI() {
    return Container(
      key: const ValueKey('initial'),
      padding: const EdgeInsets.all(32.0),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: _buildCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text( "Reconhecimento Facial", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
          const SizedBox(height: 24),
          _buildInstructionRow(Icons.lightbulb_outline, "Esteja em um ambiente bem iluminado."),
          _buildInstructionRow(Icons.visibility_off_outlined, "Deixe o rosto bem visível. Evite qualquer acessório."),
          _buildInstructionRow(Icons.sync_outlined, "Mantenha sua cabeça dentro do círculo durante todo o reconhecimento facial."),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _initializeAndShowCamera,
              style: _buildButtonStyle(),
              child: const Text("Iniciar Reconhecimento Facial"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraUI() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    return Column(
      key: const ValueKey('camera'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Tire sua foto", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        const SizedBox(height: 8),
        Text("Centralize seu rosto no círculo", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.primaryText.withOpacity(0.7))),
        const SizedBox(height: 24),
        SizedBox(
          width: 300,
          height: 400, 
          child: ClipOval(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text("Capturar Foto"),
          onPressed: _captureAndVerify,
          style: _buildButtonStyle(),
        ),
      ],
    );
  }

  Widget _buildResultUI() {
    final bool isSuccess = _verificationSuccess ?? false;
    return Container(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(32.0),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: _buildCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset( isSuccess ? 'assets/images/cadeado_ok.png' : 'assets/images/cadeado_ok.png', height: 120),
          const SizedBox(height: 24),
          Text( _message ?? "", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              if (isSuccess) {
                 Navigator.of(context).pop(); 
                 setState(() { _screenState = ScreenState.initial; }); 
              }
            },
            style: _buildButtonStyle(isSuccess: isSuccess),
            child: Text(isSuccess ? "Prosseguir" : "Tentar Novamente"),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
  );

  ButtonStyle _buildButtonStyle({bool isSuccess = true}) => ElevatedButton.styleFrom(
    backgroundColor: isSuccess ? AppColors.primaryButton : Colors.redAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
  );

  Widget _buildInstructionRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(children: [
      Icon(icon, color: AppColors.primaryButton, size: 24),
      const SizedBox(width: 16),
      Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 15, color: AppColors.primaryText.withOpacity(0.8))))
    ]),
  );
}