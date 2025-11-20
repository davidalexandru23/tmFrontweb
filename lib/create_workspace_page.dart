import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';

class CreateWorkspacePage extends StatefulWidget {
  const CreateWorkspacePage({super.key});

  @override
  State<CreateWorkspacePage> createState() => _CreateWorkspacePageState();
}

class _CreateWorkspacePageState extends State<CreateWorkspacePage> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createWorkspace() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.post('/workspaces', {
        'name': _nameController.text,
      });

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grup creat cu succes!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Grup Nou',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creează un grup nou pentru task-uri în echipă',
                style: GoogleFonts.robotoSlab(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nume Grup',
                  labelStyle: const TextStyle(color: Colors.red),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.group, color: Colors.red),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Numele grupului este obligatoriu'
                    : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createWorkspace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Creează Grup',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
