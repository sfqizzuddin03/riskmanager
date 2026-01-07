import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/portfolio_provider.dart'; // REQUIRED for logout clearing
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // 1. Password Reset Logic
  void _changePassword() async {
    if (user?.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password reset email sent to ${user!.email}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 2. Update Name Logic
  void _updateDisplayName() {
    TextEditingController nameController = TextEditingController(text: user?.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Name"),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: "Display Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await user?.updateDisplayName(nameController.text);
              await user?.reload();
              if (mounted) {
                Navigator.pop(context);
                setState(() {}); // Refresh UI
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // 3. Switch Account Logic
  void _handleSwitchAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Account'),
        content: const Text('You will be logged out to sign in with a different account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            child: const Text('Switch', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // 4. Logout Logic
  void _performLogout() async {
    // Clear local data so next user doesn't see it
    Provider.of<PortfolioProvider>(context, listen: false).clearData();
    
    // Sign out from Firebase
    await AuthService().signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    // NO SCAFFOLD. NO APP BAR. (Controlled by MainScreen now)
    return Container(
      color: settings.isDarkMode ? Colors.black : Colors.grey[100],
      child: ListView(
        children: [
          // PROFILE HEADER
          ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Text(
                user?.displayName != null && user!.displayName!.isNotEmpty
                    ? user!.displayName![0].toUpperCase()
                    : (user?.email?[0].toUpperCase() ?? "U"),
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            title: Text(user?.displayName ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user?.email ?? ""),
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _updateDisplayName),
          ),
          
          const Divider(),

          // PREFERENCES
          _sectionHeader("PREFERENCES"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.dark_mode),
            value: settings.isDarkMode,
            onChanged: (val) => settings.toggleDarkMode(val),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text("Currency"),
            subtitle: Text("Current: ${settings.currency}"),
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox(),
              items: ['USD', 'EUR', 'GBP', 'MYR'].map((val) => 
                DropdownMenuItem(value: val, child: Text(val))
              ).toList(),
              onChanged: (val) {
                if (val != null) settings.setCurrency(val);
              },
            ),
          ),
          SwitchListTile(
            title: const Text("Risk Alerts"),
            secondary: Icon(Icons.notifications_active, color: settings.notificationsEnabled ? Colors.red : Colors.grey),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(val),
          ),

          const Divider(),

          // ACCOUNT ACTIONS
          _sectionHeader("ACCOUNT"),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Reset Password"),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blue),
            title: const Text("Switch Account", style: TextStyle(color: Colors.blue)),
            onTap: _handleSwitchAccount,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out", style: TextStyle(color: Colors.red)),
            onTap: _performLogout,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}