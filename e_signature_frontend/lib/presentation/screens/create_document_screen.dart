import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';
import '../../data/repositories/document_repository.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart'; 

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentRepository = DocumentRepository();

  final _signerFullNameController = TextEditingController();
  final _signerNationalIdController = TextEditingController();
  final _signerPhoneNumberController = TextEditingController();
  final _signerEmailController = TextEditingController();

  PlatformFile? _pickedDocumentFile;
  PlatformFile? _pickedPhotoIdFile; 

  @override
  void dispose() {
    _signerFullNameController.dispose();
    _signerNationalIdController.dispose();
    _signerPhoneNumberController.dispose();
    _signerEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isDocument) async {
    final result = await FilePicker.platform.pickFiles(
      type: isDocument ? FileType.custom : FileType.image,
      allowedExtensions: isDocument ? ['pdf'] : null,
      withData: true,
    );

    if (result != null) {
      setState(() {
        if (isDocument) {
          _pickedDocumentFile = result.files.first;
        } else {
          _pickedPhotoIdFile = result.files.first;
        }
      });
    }
  }

Future<void> _createDocument() async {
    if (_pickedDocumentFile == null || _pickedPhotoIdFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Por favor, anexe o PDF e a foto de identificação.'),
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Erro de autenticação. Faça o login novamente.'),
      ));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final success = await _documentRepository.createDocumentWithFiles(
      companyId: 7,
      statusId: 1,
      documentFileName: _pickedDocumentFile!.name,
      documentFileBytes: _pickedDocumentFile!.bytes!,
      signerFullName: _signerFullNameController.text,
      signerPhoneNumber: _signerPhoneNumberController.text,
      signerEmail: _signerEmailController.text,
      signerNationalId: _signerNationalIdController.text,
      photoIdFileName: _pickedPhotoIdFile!.name,
      photoIdFileBytes: _pickedPhotoIdFile!.bytes!,
    );
    
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    navigator.pop();

    if (success) {
      scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Documento enviado com sucesso!')));
      navigator.pop();
    } else {
      scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao enviar o documento.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryText), onPressed: () => Navigator.of(context).pop()),
        title: Text('Criar Novo Documento', style: GoogleFonts.poppins(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('1. Documento para Assinatura'),
              const SizedBox(height: 16),
              _buildFileUploadWidget(isDocument: true),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('2. Dados do Signatário'),
              const SizedBox(height: 16),
              _buildTextField(controller: _signerFullNameController, label: 'Nome Completo'),
              const SizedBox(height: 16),
              _buildTextField(controller: _signerNationalIdController, label: 'CPF / CNPJ'),
              const SizedBox(height: 16),
              _buildTextField(controller: _signerPhoneNumberController, label: 'Telefone'),
              const SizedBox(height: 16),
              _buildTextField(controller: _signerEmailController, label: 'E-mail do Signatário', keyboardType: TextInputType.emailAddress),
              
              const SizedBox(height: 32),

              _buildSectionTitle('3. Foto de Identificação (ID)'),
              const SizedBox(height: 16),
              _buildFileUploadWidget(isDocument: false),

              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadWidget({required bool isDocument}) {
    final file = isDocument ? _pickedDocumentFile : _pickedPhotoIdFile;
    final title = isDocument ? 'Selecionar Arquivo PDF' : 'Selecionar Foto (ID)';
    final changeTitle = isDocument ? 'Trocar PDF' : 'Trocar Foto';

    if (file != null) {
      return _buildFileInfo(file, isDocument);
    } else {
      return OutlinedButton.icon(
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(title),
        onPressed: () => _pickFile(isDocument),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryButton,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.primaryButton),
        ),
      );
    }
  }
  
  Widget _buildFileInfo(PlatformFile file, bool isDocument) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textFieldBorder),
      ),
      child: Row(
        children: [
          Icon(isDocument ? Icons.picture_as_pdf : Icons.image, color: isDocument ? Colors.red : AppColors.primaryButton),
          const SizedBox(width: 12),
          Expanded(child: Text(file.name, style: GoogleFonts.poppins(), overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() {
              if (isDocument) _pickedDocumentFile = null;
              else _pickedPhotoIdFile = null;
            }),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) { /* ... */ return Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText));}
  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType keyboardType = TextInputType.text}) { /* ... */ return TextFormField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label), validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null); }
  Widget _buildSubmitButton() { /* ... */ return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _createDocument, icon: const Icon(Icons.send_outlined), label: const Text('Criar e Enviar'))); }
}

