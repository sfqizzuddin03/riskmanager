import 'package:flutter/material.dart';
import 'portfolio_screen.dart';
import 'risk_dashboard.dart';
import 'settings_screen.dart'; 
import 'watchlist_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Update the list to include the Settings Screen
  final List<Widget> _screens = [
    const WatchlistScreen(),
    const PortfolioScreen(),
    const RiskDashboard(),
    const SettingsScreen(), // <--- ADD THIS
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final navColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final selectedItemColor = isDarkMode ? Colors.blueAccent : Colors.blueGrey.shade900;

    return Scaffold(
      body: _screens[_currentIndex],
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: navColor,
        indicatorColor: selectedItemColor.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.remove_red_eye_outlined),
            selectedIcon: Icon(Icons.remove_red_eye),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Risk',
          ),
          // <--- NEW TAB
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}