import 'package:flutter/material.dart';
import 'package:task_manager_app/signup_page.dart';
import 'package:task_manager_app/home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:task_manager_app/api_config.dart'; // NOU
import 'package:task_manager_app/storage_service.dart'; // NOU

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storageService = StorageService(); // NOU
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final body = jsonEncode({
        "email": _emailController.text,
        "password": _passwordController.text,
      });

      // Folosim http.post simplu aici, fără interceptor
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String accessToken = data['accessToken'];
        final String refreshToken = data['refreshToken'];
        final String username = data['user']['name'];

        // NOU: Folosim funcția actualizată
        await _storageService.saveAuthData(accessToken, refreshToken, username);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(username: username),
            ),
          );
        } else {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['error']['message'] ?? 'Date incorecte';
          _showError(errorMessage);
        }
      }
    } catch (e) {
      _showError('Eroare de rețea: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Column(
            children: [
              Text(
                'ADMINISTRATOR DOSARE',
                style: GoogleFonts.robotoSlab(
                  // Font actualizat
                  color: const Color.fromARGB(255, 255, 0, 0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 20,
                ),
              ),
              Text(
                'STRICT SECRET',
                style: GoogleFonts.robotoSlab(
                  // Font actualizat
                  color: const Color.fromARGB(255, 255, 0, 0),
                  fontWeight: FontWeight.normal,
                  letterSpacing: 1,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  'assets/image.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16.0),
              // Restul UI-ului rămâne neschimbat...
              TextField(
                controller: _emailController,
                cursorColor: Colors.red,
                style: const TextStyle(color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.red),
                  hintText: 'introdu emailul...',
                  hintStyle: const TextStyle(color: Colors.redAccent),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'Parolă',
                  labelStyle: const TextStyle(color: Colors.red),
                  hintText: 'introdu parola...',
                  hintStyle: const TextStyle(color: Colors.redAccent),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Loghează-te'),
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupPage()),
                  );
                },
                child: const Text('Creează cont'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
