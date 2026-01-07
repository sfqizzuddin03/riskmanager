import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'stock_selection_screen.dart';
import 'setup_profile_screen.dart';
import 'package:provider/provider.dart';
import '../providers/portfolio_provider.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _initialCapitalController = TextEditingController();
  final AuthService _auth = AuthService();//
  
  bool _isLogin = true;
  bool _isLoading = false;

 void _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final capital = _initialCapitalController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (!_isLogin && capital.isEmpty) {
      _showErrorDialog('Please enter initial capital');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        // CASE A: User is Logging In
        await _auth.signIn(email, password);
      } else {
        // CASE B: User is Registering (New Account)
        final initialCapital = double.tryParse(capital) ?? 10000.0;
        await _auth.register(email, password, initialCapital);
      }

      if (_auth.isLoggedIn) {
        // CRITICAL FIX: Reload data for the new user immediately
        if (mounted) {
           Provider.of<PortfolioProvider>(context, listen: false).loadPortfolio();
        }

        if (!_isLogin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupProfileScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen(selectedStocks: [])), // Pass empty, we will load saved ones
          );
        }
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Manager Pro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_balance_wallet,
          size: 64,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 20),
        Text(
          _isLogin ? 'Welcome Back' : 'Create Account',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 15),
        
        if (!_isLogin) ...[
          TextField(
            controller: _initialCapitalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Initial Capital (\$)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 15),
        ],
        
                      
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isLogin ? 'Login' : 'Register'),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: Text(
                      _isLogin ? 'Create new account' : 'Already have an account?',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}