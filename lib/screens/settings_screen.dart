import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/theme_service.dart'; // Import ThemeService

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? path = await DatabaseService.loadProfileImage(user.uid);
      if (mounted) {
        setState(() {
          _profileImagePath = path;
        });
      }
    }
  }

  // --- PICK IMAGE LOGIC ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImagePath = image.path;
      });
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save local path to Firestore (Note: For a real production app, 
        // you would upload this file to Firebase Storage and save the URL)
        await DatabaseService.saveProfileImage(user.uid, image.path);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Use Theme colors
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // --- 1. PROFILE PICTURE ---
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueGrey.shade200,
                    backgroundImage: _profileImagePath != null 
                        ? FileImage(File(_profileImagePath!)) 
                        : null,
                    child: _profileImagePath == null
                        ? Text(
                            user?.email?.substring(0, 1).toUpperCase() ?? "U",
                            style: const TextStyle(fontSize: 50, color: Colors.white),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            Text(
              user?.email ?? "User",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              "Tap photo to update",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // --- 2. SETTINGS LIST ---
            _buildSectionHeader("Preferences", textColor),
            
            // THEME TOGGLE
            Container(
              color: cardColor,
              child: SwitchListTile(
                title: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text("Toggle app appearance"),
                secondary: Icon(Icons.dark_mode, color: isDarkMode ? Colors.blueAccent : Colors.grey),
                value: isDarkMode,
                onChanged: (val) {
                  // Toggle Theme globally
                  ThemeService().toggleTheme(val);
                },
              ),
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
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Container(
      color: cardColor,
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