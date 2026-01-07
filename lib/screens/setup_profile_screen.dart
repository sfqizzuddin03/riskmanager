import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // REQUIRED
import 'stock_selection_screen.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  File? _imageFile; // Stores the picked image
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _completeSetup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Update Display Name
      await user?.updateDisplayName(_nameController.text);
      
      // CRITICAL FIX: Save the image path to database
      if (_imageFile != null) {
        await DatabaseService.saveProfileImage(user!.uid, _imageFile!.path);
      }
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StockSelectionScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Profile"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text("Let's get you ready!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            // IMAGE PICKER
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to upload photo", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 30),

            // NAME INPUT
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 20),

             // Currency Preference
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => DropdownButtonFormField<String>(
                value: settings.currency,
                decoration: const InputDecoration(
                  labelText: "Preferred Currency",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: ['USD', 'EUR', 'GBP', 'MYR'].map((val) => 
                  DropdownMenuItem(value: val, child: Text(val))
                ).toList(),
                onChanged: (val) {
                  if (val != null) settings.setCurrency(val);
                },
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeSetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Complete Setup"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}