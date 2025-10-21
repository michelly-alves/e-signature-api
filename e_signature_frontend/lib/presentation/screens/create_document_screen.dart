import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../theme/app_colors.dart';
import '../../data/repositories/document_repository.dart';

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentRepository = DocumentRepository();

  final _titleController = TextEditingController();

  final _signerFullNameController = TextEditingController();
  final _signerNationalIdController = TextEditingController();
  final _signerPhoneNumberController = TextEditingController();
  final _signerEmailController = TextEditingController();

  PlatformFile? _pickedFile;

  @override
  void dispose() {
    _titleController.dispose();
    _signerFullNameController.dispose();
    _signerNationalIdController.dispose();
    _signerPhoneNumberController.dispose();
    _signerEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _createDocument() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Por favor, selecione um arquivo PDF.'),
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _documentRepository.createDocumentWithFile(
      companyId: 1,
      statusId: 1,

      fileName: _pickedFile!.name,
      fileBytes: _pickedFile!.bytes!,
      signerFullName: _signerFullNameController.text,
      signerPhoneNumber: _signerPhoneNumberController.text,
      signerEmail: _signerEmailController.text,
      signerNationalId: _signerNationalIdController.text,
    );
    
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    navigator.pop(); 

    if (success) {
      scaffoldMessenger.showSnackBar(const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Documento enviado com sucesso!'),
      ));
      navigator.pop(); 
    } else {
      scaffoldMessenger.showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Erro ao enviar o documento.'),
      ));
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
        title: Text(
          'Criar Novo Documento',
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1. Anexar o PDF'),
                const SizedBox(height: 16),
                _buildFileUploadButton(),
                if (_pickedFile != null) ...[
                  const SizedBox(height: 16),
                  _buildFileInfo(),
                ],
                const SizedBox(height: 32),
                _buildSectionTitle('2. Adicionar Signatário Principal'),
                const SizedBox(height: 16),
                _buildTextField(controller: _signerFullNameController, label: 'Nome Completo'),
                const SizedBox(height: 16),
                _buildTextField(controller: _signerNationalIdController, label: 'CPF / CNPJ'),
                const SizedBox(height: 16),
                _buildTextField(controller: _signerPhoneNumberController, label: 'Telefone'),
                const SizedBox(height: 16),
                _buildTextField(controller: _signerEmailController, label: 'E-mail do Signatário', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 40),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
 
  Widget _buildFileUploadButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(_pickedFile == null ? 'Selecionar Arquivo PDF' : 'Trocar Arquivo'),
      onPressed: _pickDocument,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryButton,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.primaryButton),
      ),
    );
  }
  
  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textFieldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pickedFile!.name,
              style: GoogleFonts.poppins(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _pickedFile = null),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryText,
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.primaryText.withOpacity(0.7)),
        filled: true,
        fillColor: AppColors.textFieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryButton, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo é obrigatório.';
        }
        if (label.contains('E-mail') && !value.contains('@')) {
          return 'Por favor, insira um e-mail válido.';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.send_outlined, color: Colors.white),
        label: Text(
          'Criar e Enviar',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        onPressed: _createDocument,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}