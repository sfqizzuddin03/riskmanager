import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- FIXED: Added missing import

// --- SCREEN 1: TERMS & POLICIES ---
class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Policies")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Investive Terms of Service", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            Text("Last Updated: January 2026", style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            
            _buildSection("1. Risk Disclosure", "Trading financial assets involves a high level of risk. The data provided in this application is for educational and risk management purposes only. We are not responsible for any financial losses."),
            _buildSection("2. Data Usage", "We collect your email and profile picture to personalize your experience. Your portfolio data is stored securely using Google Firebase."),
            _buildSection("3. User Responsibilities", "You are responsible for maintaining the confidentiality of your account credentials. Any activity that occurs under your account is your responsibility."),
            
            const SizedBox(height: 30),
            Center(
              child: Text("© 2026 Investive Inc.", style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(body, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

// --- SCREEN 2: SECURITY PERMISSIONS ---
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Security & Permissions")),
      body: ListView(
        children: [
          _buildPermissionItem(
            context,
            icon: Icons.image,
            title: "Photo Gallery",
            status: "Authorized",
            desc: "Used to update your profile picture.",
          ),
          _buildPermissionItem(
            context,
            icon: Icons.wifi,
            title: "Internet Access",
            status: "Authorized",
            desc: "Required to fetch real-time market data.",
          ),
          _buildPermissionItem(
            context,
            icon: Icons.notifications,
            title: "Notifications",
            status: "Optional",
            desc: "Used for price alerts and risk warnings.",
          ),
          const Divider(),

          // --- CHANGE PASSWORD BUTTON ---
          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.blueGrey),
            title: const Text("Change Password"),
            subtitle: const Text("Send password reset email"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && user.email != null) {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Reset email sent! Check your inbox."), 
                      backgroundColor: Colors.green
                    ),
                  );
                }
              }
            },
          ),
        ], 
      )
    );
  }

  Widget _buildPermissionItem(BuildContext context, {required IconData icon, required String title, required String status, required String desc}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = status == "Authorized" ? Colors.green : Colors.orange;

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(desc, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        )
      ],
    );
  }
}