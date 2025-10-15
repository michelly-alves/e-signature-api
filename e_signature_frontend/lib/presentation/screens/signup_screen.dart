import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart'; 

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool isPessoaFisica = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: isPessoaFisica
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.backgroundDark,
                    AppColors.backgroundLight,
                  ],
                ),
              )
            : const BoxDecoration( 
                color: AppColors.backgroundWarm,
              ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cadastre-se',
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: isPessoaFisica ? AppColors.primaryPink : AppColors.primaryDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildProfileTypeSwitcher(),
                        const SizedBox(height: 32),
                        
                        if (isPessoaFisica)
                          _buildPessoaFisicaForm()
                        else
                          _buildEmpresaForm(),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDarkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Entrar',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (MediaQuery.of(context).size.width > 900)
                  const SizedBox(width: 64),
                if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    child: Image.asset(
                      'assets/images/assinatura_garota_perfil.png', 
                      height: 500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPessoaFisicaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledTextField(label: 'Nome'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'CPF'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'Data de Nascimento'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'E-mail'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'Senha', isPassword: true),
      ],
    );
  }

  Widget _buildEmpresaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledTextField(label: 'Nome fantasia'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'CNPJ'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'E-mail'),
        const SizedBox(height: 24),
        _buildLabeledTextField(label: 'Senha', isPassword: true),
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildProfileTypeSwitcher() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (!isPessoaFisica) {
              setState(() => isPessoaFisica = true);
            }
          },
          child: Text(
            'Pessoa Física',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: isPessoaFisica ? AppColors.primaryPink : AppColors.textLight,
              fontWeight: isPessoaFisica ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () {
            if (isPessoaFisica) {
              setState(() => isPessoaFisica = false);
            }
          },
          child: Text(
            'Empresa',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: !isPessoaFisica ? AppColors.primaryPink : AppColors.textLight,
              fontWeight: !isPessoaFisica ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledTextField({required String label, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              color: AppColors.textLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFCF8F3), 
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF9E9281),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryDarkBlue,
                width: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}