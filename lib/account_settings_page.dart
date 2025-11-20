import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/login_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final response = await _apiClient.get('/users/me');
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setState(() {
          _userName = user['name'];
          _userEmail = user['email'];
        });
      }
    } catch (e) {
      // Error loading user info
    }
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Parolele nu se potrivesc.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.post('/auth/change-password', {
        'oldPassword': _oldPasswordController.text,
        'newPassword': _newPasswordController.text,
      });

      if (response.statusCode == 200) {
        _showSuccess('Parola a fost schimbată cu succes. Vă rugăm să vă autentificați din nou.');
        
        // Clear storage and navigate to login
        await _storage.clearAuthData();
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError(error);
      }
    } catch (e) {
      _showError('Eroare: $e');
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Setări Cont',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informații Cont',
                      style: GoogleFonts.robotoSlab(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.red),
                      title: Text(
                        _userName ?? 'Se încarcă...',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Nume',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.red),
                      title: Text(
                        _userEmail ?? 'Se încarcă...',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Email',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Change Password Section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schimbă Parola',
                        style: GoogleFonts.robotoSlab(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Old Password
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Parola Veche',
                          labelStyle: const TextStyle(color: Colors.red),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOld ? Icons.visibility_off : Icons.visibility,
                              color: Colors.red,
                            ),
                            onPressed: () => setState(() => _obscureOld = !_obscureOld),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Parola veche este obligatorie'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Parola Nouă',
                          labelStyle: const TextStyle(color: Colors.red),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_off : Icons.visibility,
                              color: Colors.red,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Parola nouă este obligatorie';
                          }
                          if (value.length < 6) {
                            return 'Parola trebuie să aibă minim 6 caractere';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirmă Parola',
                          labelStyle: const TextStyle(color: Colors.red),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: Colors.red,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Confirmarea parolei este obligatorie'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Schimbă Parola',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
