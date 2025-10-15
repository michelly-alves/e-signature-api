import 'package:e_signature_frontend/presentation/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isPessoaFisicaLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: isPessoaFisicaLogin
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
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    child: Image.asset(
                      'assets/images/garota_notebook.png', 
                      height: 500,
                    ),
                  ),
                if (MediaQuery.of(context).size.width > 900)
                  const SizedBox(width: 64),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPink,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          isPessoaFisicaLogin
                              ? 'Número do CPF ou Email'
                              : 'Número do CNPJ ou Email',
                          style: GoogleFonts.poppins(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(),
                        const SizedBox(height: 24),
                        Text(
                          'Senha',
                          style: GoogleFonts.poppins(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(isPassword: true),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Adicionar lógica de login
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDarkBlue,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
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
                        const SizedBox(height: 24),
                        _buildLoginTypeSwitcher(),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Text(
                                'Esqueci minha senha',
                                style: GoogleFonts.poppins(
                                    color: AppColors.textLight),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                                  );
                                },
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Não tem uma conta? ',
                                    style: GoogleFonts.poppins(
                                        color: AppColors.textLight),
                                    children: [
                                      TextSpan(
                                        text: 'Cadastre-se',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primaryDarkBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({bool isPassword = false}) {
    return TextFormField(
      obscureText: isPassword,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDarkBlue),
        ),
      ),
    );
  }

  Widget _buildLoginTypeSwitcher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isPessoaFisicaLogin) {
              setState(() {
                isPessoaFisicaLogin = false;
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login como Empresa',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: !isPessoaFisicaLogin
                      ? AppColors.primaryPink
                      : AppColors.textLight,
                  fontWeight: !isPessoaFisicaLogin
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if (!isPessoaFisicaLogin)
                Container(
                  width: 150, 
                  height: 2,
                  color: AppColors.primaryPink,
                  margin: const EdgeInsets.only(top: 2),
                )
            ],
          ),
        ),
        const SizedBox(height: 8), 
        GestureDetector(
          onTap: () {
            if (!isPessoaFisicaLogin) { 
              setState(() {
                isPessoaFisicaLogin = true;
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login como Pessoa Física',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isPessoaFisicaLogin
                      ? AppColors.primaryPink
                      : AppColors.textLight,
                  fontWeight:
                      isPessoaFisicaLogin ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isPessoaFisicaLogin)
                Container(
                  width: 170,
                  height: 2,
                  color: AppColors.primaryPink,
                  margin: const EdgeInsets.only(top: 2),
                )
            ],
          ),
        ),
      ],
    );
  }
}