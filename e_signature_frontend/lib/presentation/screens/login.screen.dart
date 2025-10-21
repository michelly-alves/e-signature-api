import 'package:e_signature_frontend/presentation/screens/home.screen.dart';
import 'package:e_signature_frontend/presentation/screens/signup_screen.dart'; 
import 'package:e_signature_frontend/presentation/screens/facial_recognition_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/api_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isPessoaFisicaLogin = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> login(String email, String password) async {
    final url = Uri.parse(ApiConstants.baseUrl + ApiConstants.signupEndpoint); 
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token']; 
      } else if (response.statusCode == 401) {
        return null; 
      } else {
        throw Exception('Erro ao conectar com o servidor');
      }
    } catch (e) {
      print('Erro no login: $e');
      return null;
    }
  }

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
                        _buildTextField(controller: _emailController),
                        const SizedBox(height: 24),
                        Text(
                          'Senha',
                          style: GoogleFonts.poppins(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _passwordController, isPassword: true),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = _emailController.text;
                              final password = _passwordController.text;

                              final token = await login(email, password);

                              if (token != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HomeScreen(), 
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Credenciais inválidas')),
                                );
                              }
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

  Widget _buildTextField({bool isPassword = false, TextEditingController? controller}) {
    return TextFormField(
      controller: controller,
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
