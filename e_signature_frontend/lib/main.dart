import 'package:e_signature_frontend/presentation/screens/home.screen.dart';
import 'package:e_signature_frontend/presentation/screens/login.screen.dart';
import 'package:e_signature_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'E-Signature App',
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primaryButton,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
home: Consumer<AuthProvider>(
  builder: (context, auth, _) {
    if (auth.isAuthenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  },
),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

