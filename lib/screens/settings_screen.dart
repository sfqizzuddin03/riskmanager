import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/theme_service.dart';
import 'legal_security_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();
  
  // Local state for notifications (Visual only for now)
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? path = await DatabaseService.loadProfileImage(user.uid);
      if (mounted) setState(() => _profileImagePath = path);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _profileImagePath = image.path);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Settings")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // --- PROFILE HEADER ---
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueGrey.shade200,
                    backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null,
                    child: _profileImagePath == null
                        ? Text(user?.email?.substring(0, 1).toUpperCase() ?? "U", style: const TextStyle(fontSize: 40, color: Colors.white))
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(user?.email ?? "User", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            
            const SizedBox(height: 30),

            // --- SECTION 1: GENERAL ---
            _buildSectionHeader("General", textColor),
            Container(
              color: cardColor,
              child: Column(
                children: [
                  // Theme Toggle
                  SwitchListTile(
                    title: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    secondary: Icon(Icons.dark_mode, color: isDarkMode ? Colors.blueAccent : Colors.grey),
                    value: isDarkMode,
                    onChanged: (val) => ThemeService().toggleTheme(val),
                  ),
                  const Divider(height: 1),
                  // Notifications Toggle
                  SwitchListTile(
                    title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: const Text("Price alerts & warnings"),
                    secondary: const Icon(Icons.notifications_active, color: Colors.orange),
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? "Notifications Enabled" : "Notifications Disabled"), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- SECTION 2: SECURITY & LEGAL ---
            _buildSectionHeader("Security & Legal", textColor),
            Container(
              color: cardColor,
              child: Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: Icons.security,
                    title: "Security & Permissions",
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityScreen())),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context,
                    icon: Icons.policy,
                    title: "Terms & Policies",
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsPolicyScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- SECTION 3: ACCOUNT ---
            _buildSectionHeader("Account", textColor),
            Container(
              color: cardColor,
              child: _buildSettingsTile(
                context,
                icon: Icons.logout,
                title: "Sign Out",
                color: Colors.redAccent,
                onTap: () => _signOut(context),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? Colors.blueGrey).withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color ?? Colors.blueGrey),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
      trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}