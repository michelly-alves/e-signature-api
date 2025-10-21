import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool isPessoaFisica = false; 
  final _authRepository = AuthRepository();

  final nameController = TextEditingController();
  final cpfController = TextEditingController();
  final birthController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final companyNameController = TextEditingController();
  final cnpjController = TextEditingController();
  final companyEmailController = TextEditingController();
  final companyPasswordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    cpfController.dispose();
    birthController.dispose();
    emailController.dispose();
    passwordController.dispose();
    companyNameController.dispose();
    cnpjController.dispose();
    companyEmailController.dispose();
    companyPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isFormInvalid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    final userData = isPessoaFisica
        ? {
            "email": emailController.text,
            "password": passwordController.text,
            "role": "Signer", 
            "full_name": nameController.text,
            "national_id": cpfController.text,
            "phone_number": "85999999999" 
          }
        : {
            "email": companyEmailController.text,
            "password": companyPasswordController.text,
            "role": "Company", 
            "legal_name": companyNameController.text,
            "tax_id": cnpjController.text,
          };

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await _authRepository.createUser(userData);

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Cadastro realizado com sucesso!')),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao cadastrar usuário. Verifique os dados.')),
      );
    }
  }

  bool _isFormInvalid() {
    if (isPessoaFisica) {
      return nameController.text.isEmpty ||
          cpfController.text.isEmpty ||
          emailController.text.isEmpty ||
          passwordController.text.isEmpty;
    } else {
      return companyNameController.text.isEmpty ||
          cnpjController.text.isEmpty ||
          companyEmailController.text.isEmpty ||
          companyPasswordController.text.isEmpty;
              }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildFormSide(),
        ),
        Expanded(
          flex: 4,
          child: _buildImageSide(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFormSide(),
          const SizedBox(height: 40),
          _buildImageSide(),
        ],
      ),
    );
  }

  Widget _buildFormSide() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cadastre-se',
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 24),
          _buildProfileTypeSwitcher(),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isPessoaFisica
                ? _buildPessoaFisicaForm()
                : _buildEmpresaForm(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Cadastrar',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSide() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Image.asset(
        'assets/images/assinatura_garota_perfil.png',
        fit: BoxFit.contain,
        height: 450,
      ),
    );
  }

  Widget _buildPessoaFisicaForm() {
    return Column(
      key: const ValueKey('pessoaFisicaForm'),
      children: [
        _buildLabeledTextField(controller: nameController, label: 'Nome completo'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: cpfController, label: 'CPF'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: emailController, label: 'E-mail'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: passwordController, label: 'Senha', isPassword: true),
      ],
    );
  }

  Widget _buildEmpresaForm() {
    return Column(
      key: const ValueKey('empresaForm'),
      children: [
        _buildLabeledTextField(controller: companyNameController, label: 'Nome fantasia'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: cnpjController, label: 'CNPJ'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: companyEmailController, label: 'E-mail da Empresa'),
        const SizedBox(height: 16),
        _buildLabeledTextField(controller: companyPasswordController, label: 'Senha', isPassword: true),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProfileTypeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSwitcherButton('Empresa', !isPessoaFisica),
          ),
          Expanded(
            child: _buildSwitcherButton('Pessoa Física', isPessoaFisica),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isPessoaFisica = (text == 'Pessoa Física');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: AppColors.primaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.primaryText.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
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
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
        ),
      ],
    );
  }
}
