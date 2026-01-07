import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/settings_provider.dart'; // Import the new provider
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PortfolioProvider()..loadPortfolio()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()), // Add this line
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to SettingsProvider for Dark Mode
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Investive',
      debugShowCheckedModeBanner: false,
      // REAL THEME SWITCHING LOGIC
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const LoginScreen(),
    );
  }
}