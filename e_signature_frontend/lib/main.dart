import 'package:flutter/material.dart';
import 'presentation/screens/login.screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Signature App',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5B9E)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}