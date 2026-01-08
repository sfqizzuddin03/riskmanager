import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/portfolio_screen.dart'; 
import 'screens/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const InvestiveApp());
}

class InvestiveApp extends StatelessWidget {
  const InvestiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Investive',
      debugShowCheckedModeBanner: false,
      // theme: ThemeData.light(), // Set your themes here if needed
      // darkTheme: ThemeData.dark(),
      // themeMode: ThemeMode.system,

      // THE "DOORMAN" LOGIC
          home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          // FIX: Point to MainLayout instead of PortfolioScreen
          return const MainLayout(); 
        }

          return const LoginScreen();
        },
      ),
    );
  }
}
