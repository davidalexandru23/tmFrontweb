import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:task_manager_app/api_config.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storageService = StorageService();
  bool _isLoading = false;
  String _selectedRole = 'MEMBER';

  final List<String> _roles = ['OWNER', 'LEADER', 'MEMBER'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Parolele nu se potrivesc!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final body = jsonEncode({
        "name": _nameController.text,
        "email": _emailController.text,
        "password": _passwordController.text,
        "role": _selectedRole,
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String accessToken = data['accessToken'];
        final String refreshToken = data['refreshToken'];
        final String username = data['user']['name'];

        await _storageService.saveAuthData(accessToken, refreshToken, username);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(username: username),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['error']['message'] ?? 'A apărut o eroare';
        _showError(errorMessage);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Column(
            children: [
              Text(
                'ADMINISTRATOR DOSARE',
                style: GoogleFonts.robotoSlab(
                  color: const Color.fromARGB(255, 255, 0, 0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 17,
                ),
              ),
              Text(
                'STRICT SECRET',
                style: GoogleFonts.robotoSlab(
                  color: const Color.fromARGB(255, 255, 0, 0),
                  fontWeight: FontWeight.normal,
                  letterSpacing: 1,
                  fontSize: 12,
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
              const Text(
                'Creează-ți un cont.',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _nameController,
                cursorColor: Colors.red,
                style: const TextStyle(color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Colors.red),
                  hintText: 'Username ofițer...',
                  hintStyle: const TextStyle(color: Colors.redAccent),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _emailController,
                cursorColor: Colors.red,
                style: const TextStyle(color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.red),
                  hintText: 'george.simion@sie.ro...',
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
              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.red),
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  labelStyle: TextStyle(color: Colors.red),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  ),
                ),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
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
              const SizedBox(height: 16.0),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'Introdu parola din nou',
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
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Creează cont'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
