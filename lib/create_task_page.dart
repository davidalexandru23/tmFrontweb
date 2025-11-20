import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/location_picker_dialog.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();

  // Controlere pentru formular
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Starea pentru datele încărcate
  late Future<List<dynamic>> _workspacesFuture;
  List<dynamic>? _members; // Membrii workspace-ului selectat

  // Starea pentru valorile selectate
  String? _selectedWorkspaceId;
  String? _selectedAssigneeId;
  DateTime? _selectedDate;
  double? _selectedLatitude;
  double? _selectedLongitude;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Încărcăm grupurile de la început
    _workspacesFuture = _fetchWorkspaces();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Funcții de Încărcare Date ---

  Future<List<dynamic>> _fetchWorkspaces() async {
    try {
      final response = await _apiClient.get('/workspaces');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Nu s-au putut încărca grupurile');
      }
    } catch (e) {
      throw Exception('Eroare rețea (grupuri): $e');
    }
  }

  // Se declanșează când se schimbă grupul
  Future<void> _onWorkspaceChanged(String? workspaceId) async {
    if (workspaceId == null) return;

    setState(() {
      _selectedWorkspaceId = workspaceId;
      _members = null; // Resetează lista de membri
      _selectedAssigneeId = null; // Resetează membrul selectat
      _isLoading = true; // Arată un spinner lângă al doilea dropdown
    });

    try {
      // Cerem detaliile grupului, care includ lista de membri
      final response = await _apiClient.get('/workspaces/$workspaceId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('RĂSPUNS MEMBRI GRUP: $data');
        setState(() {
          _members = data['members'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Nu s-au putut încărca membrii');
      }
    } catch (e) {
      _showError('Eroare: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Funcții Utilitare ---

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectLocation() async {
    // Open a simple dialog with a map picker
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLat: _selectedLatitude ?? 44.4268,
        initialLng: _selectedLongitude ?? 26.1025,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['lat'];
        _selectedLongitude = result['lng'];
      });
    }
  }

  // --- Funcția Principală de Salvare ---

  Future<void> _handleCreateTask() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Validare eșuată
    }
    
    // Workspace is optional now
    if (_selectedWorkspaceId != null && _selectedAssigneeId == null) {
      _showError('Dacă alegi un grup, trebuie să alegi și un destinatar.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final body = {
        if (_selectedWorkspaceId != null) 'workspaceId': _selectedWorkspaceId,
        'title': _titleController.text,
        if (_descriptionController.text.isNotEmpty) 'description': _descriptionController.text,
        if (_selectedAssigneeId != null) 'assigneeId': _selectedAssigneeId,
        if (_selectedDate != null) 'dueDate': _selectedDate!.toUtc().toIso8601String(),
        if (_selectedLatitude != null) 'latitude': _selectedLatitude,
        if (_selectedLongitude != null) 'longitude': _selectedLongitude,
      };

      final response = await _apiClient.post('/tasks', body);

      if (response.statusCode == 201) {
        // SUCCES
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sarcină creată cu succes!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Trimite 'true' înapoi la HomePage
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError('Eroare server: $error');
      }
    } catch (e) {
      _showError('Eroare rețea: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Sarcină Nouă',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Titlu ---
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Titlu Sarcină'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Titlul e obligatoriu'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- Descriere ---
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Descriere (opțional)'),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // --- Dropdown Grupuri ---
              FutureBuilder<List<dynamic>>(
                future: _workspacesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text(
                      'Nu s-au găsit grupuri.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final workspaces = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedWorkspaceId,
                    hint: const Text(
                      'Selectează Grupul',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(null),
                    items: workspaces.map((ws) {
                      return DropdownMenuItem<String>(
                        value: ws['id'] as String,
                        child: Text(ws['name'] as String),
                      );
                    }).toList(),
                    onChanged:
                        _onWorkspaceChanged, // Declansează încărcarea membrilor
                    validator: null, // Workspace is now optional
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- Dropdown Membri ---
              if (_isLoading && _members == null)
                const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                )
              // ... în create_task_page.dart, în funcția build()
              else if (_members != null)
                DropdownButtonFormField<String>(
                  initialValue: _selectedAssigneeId,
                  hint: const Text(
                    'Alocă unui membru',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(null),
                  items: _members!
                      .map((member) {
                        // NOU: Structura reală (din debug) este PLATĂ
                        // {id: "...", name: "...", email: "...", role: "..."}

                        // Verificare de siguranță
                        if (member['id'] == null || member['name'] == null) {
                          return null; // Ignoră acest membru dacă datele sunt corupte
                        }

                        final userId = member['id'] as String;
                        final userName = member['name'] as String;

                        return DropdownMenuItem<String>(
                          value: userId,
                          child: Text(userName),
                        );
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(), // Filtrăm valorile null // Filtrăm valorile null
                   onChanged: (value) {
                     setState(() {
                       _selectedAssigneeId = value;
                     });
                   },
                   validator: null, // Optional if workspace is selected
                ),
              const SizedBox(height: 24),

              // --- Selector Locație ---
              ListTile(
                tileColor: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(
                  _selectedLatitude == null
                      ? 'Selectează locația (opțional)'
                      : 'Locație: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: _selectedLatitude == null
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                onTap: _selectLocation,
              ),
              const SizedBox(height: 16),

              // --- Selector Dată ---
              ListTile(
                tileColor: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                leading: const Icon(Icons.calendar_today, color: Colors.red),
                title: Text(
                  _selectedDate == null
                      ? 'Selectează termenul limită (opțional)'
                      : 'Termen: ${_selectedDate.toString().substring(0, 10)}',
                  style: TextStyle(
                    color: _selectedDate == null
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 32),

              // --- Buton Salvare ---
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCreateTask,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvează Sarcina'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper pentru decorațiunea TextField-urilor
  InputDecoration _buildInputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.red),
      hintStyle: const TextStyle(color: Colors.redAccent),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2.0),
      ),
    );
  }
}
