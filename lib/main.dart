import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/theme_service.dart';
import 'services/database_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  

  // Load saved theme preference
  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(const InvestiveApp());
}

class InvestiveApp extends StatelessWidget {
  const InvestiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to Theme Changes
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Investive',
          debugShowCheckedModeBanner: false,
          
          // Define Professional Themes
          themeMode: ThemeService().themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blueGrey,
            scaffoldBackgroundColor: Colors.grey[100],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blueGrey,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),

          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) {
                return const MainLayout();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}