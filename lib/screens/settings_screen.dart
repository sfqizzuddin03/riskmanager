import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // The StreamBuilder in main.dart will see you signed out 
    // and automatically show the LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(color: textColor)),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // --- 1. PROFILE HEADER ---
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueGrey,
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? "U",
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              user?.email ?? "User",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 30),

            // --- 2. SETTINGS LIST ---
            _buildSectionHeader("Preferences", textColor),
            
            _buildSettingsTile(
              context, 
              icon: Icons.dark_mode, 
              title: "App Theme", 
              subtitle: "System Default",
              onTap: () {}, // You can add theme toggle logic later
            ),

            const Divider(),
            
            _buildSectionHeader("Account", textColor),
            
            _buildSettingsTile(
              context, 
              icon: Icons.logout, 
              title: "Sign Out", 
              subtitle: "Log out of your account",
              color: Colors.redAccent,
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: textColor.withOpacity(0.5), 
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? Colors.blueGrey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.blueGrey),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.6))),
        trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}