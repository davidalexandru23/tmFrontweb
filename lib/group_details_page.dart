import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';

class GroupDetailsPage extends StatefulWidget {
  final String workspaceId;
  final String currentUsername;
  final String userRole; // Rolul tău în acest grup (ex: 'OWNER', 'LEADER')
  final ApiClient apiClient = ApiClient();

  GroupDetailsPage({
    super.key,
    required this.workspaceId,
    required this.currentUsername,
    required this.userRole,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late Future<Map<String, dynamic>> _groupDetailsFuture;

  // Stări pentru dialogul de adăugare membru
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _selectedRoleForAdd = 'MEMBER';

  @override
  void initState() {
    super.initState();
    _groupDetailsFuture = _fetchGroupDetails();
  }

  Future<Map<String, dynamic>> _fetchGroupDetails() async {
    try {
      final response = await widget.apiClient.get(
        '/workspaces/${widget.workspaceId}',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Eroare la încărcarea detaliilor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Eroare rețea: $e');
    }
  }

  // --- Funcții Helper pentru Notificări ---
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

  // --- Logica de Adăugare Membru ---

  // Pasul 1: Caută utilizatori
  // În lib/group_details_page.dart

  Future<void> _searchUsers(String query, StateSetter setStateInDialog) async {
    if (query.isEmpty) {
      setStateInDialog(() {
        _searchResults = []; // Golește rezultatele dacă interogarea e goală
      });
      return;
    }

    setStateInDialog(() {
      _isSearching = true;
    });

    try {
      final response = await widget.apiClient.get('/users', {'q': query});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // --- AICI ESTE CORECȚIA ---
        List<dynamic> results;
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          // Cazul 1: Serverul a returnat un obiect (ex: cu paginare)
          results = data['data'] ?? [];
        } else if (data is List<dynamic>) {
          // Cazul 2: Serverul a returnat direct lista (ceea ce se întâmplă acum)
          results = data;
        } else {
          // Cazul 3: Format neașteptat
          results = [];
        }
        // --- FINALUL CORECȚIEI ---

        setStateInDialog(() {
          _searchResults = results; // Atribuim lista corectă
          _isSearching = false;
        });
      } else {
        // Încercăm să citim eroarea JSON de la server
        String serverError = response.body;
        try {
          final errorData = jsonDecode(response.body);
          serverError =
              errorData['error']['message'] ??
              'Eroare necunoscută de la server';
        } catch (e) {
          // Nu a fost JSON
        }
        throw Exception(serverError); // Aruncăm eroarea reală
      }
    } catch (e) {
      setStateInDialog(() {
        _isSearching = false;
      });
      _showError(
        "Eroare căutare: ${e.toString().replaceAll("Exception: ", "")}",
      );
    }
  }

  // Pasul 2: Adaugă membrul selectat
  Future<void> _handleAddMember(
    String userId,
    String role,
    BuildContext dialogContext,
  ) async {
    Navigator.of(dialogContext).pop(); // Închide dialogul de căutare

    try {
      final response = await widget.apiClient.post(
        '/workspaces/${widget.workspaceId}/members',
        {'userId': userId, 'role': role},
      );
      if (response.statusCode == 201) {
        _showSuccess("Membru adăugat cu succes!");
        // Reîmprospătează detaliile grupului
        setState(() {
          _groupDetailsFuture = _fetchGroupDetails();
        });
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError("Eroare: $error");
      }
    } catch (e) {
      _showError("Eroare rețea: $e");
    }
  }

  // Pasul 3: Afișează dialogul principal
  void _showAddMemberDialog() {
    _searchQuery = '';
    _searchResults = [];
    _selectedRoleForAdd = 'MEMBER';

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Folosim StatefulBuilder pentru a permite actualizarea stării dialogului
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                "Adaugă Membru",
                style: GoogleFonts.robotoSlab(color: Colors.red),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Câmpul de căutare
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Caută după email sau nume...",
                        labelStyle: const TextStyle(color: Colors.redAccent),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Colors.red),
                          onPressed: () =>
                              _searchUsers(_searchQuery, setStateInDialog),
                        ),
                      ),
                      onChanged: (value) => _searchQuery = value,
                    ),
                    // Dropdown pentru Rol
                    DropdownButton<String>(
                      value: _selectedRoleForAdd,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: ['MEMBER', 'LEADER'].map((role) {
                        return DropdownMenuItem(value: role, child: Text(role));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateInDialog(() {
                            _selectedRoleForAdd = value;
                          });
                        }
                      },
                    ),
                    const Divider(color: Colors.grey),
                    // Lista de rezultate
                    _isSearching
                        ? const CircularProgressIndicator(color: Colors.red)
                        : Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              // ...
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];

                                // NOU: Citim datele în siguranță (ca String-uri nullable)
                                final String? userId = user['id'] as String?;
                                final String userName =
                                    user['name'] as String? ??
                                    'Nume Indisponibil';
                                final String userEmail =
                                    user['email'] as String? ??
                                    'Email Indisponibil';

                                // Dacă un utilizator returnat nu are ID, nu-l afișăm
                                if (userId == null) {
                                  return const SizedBox.shrink(); // Un widget gol
                                }

                                return ListTile(
                                  leading: const Icon(
                                    Icons.person,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    userName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    userEmail,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  onTap: () => _handleAddMember(
                                    userId,
                                    _selectedRoleForAdd,
                                    dialogContext,
                                  ),
                                );
                              },
                              // ...
                            ),
                          ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    "Anulează",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canAddMembers =
        (widget.userRole == 'OWNER' || widget.userRole == 'LEADER');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Detalii Grup',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Eroare: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Grup negăsit.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final group = snapshot.data!;
          final members = (group['members'] as List? ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'] ?? 'Nume Grup',
                  style: GoogleFonts.robotoSlab(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.grey, height: 32),
                Text(
                  'Membri Grup',
                  style: GoogleFonts.robotoSlab(
                    color: Colors.red,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    // final user = member['user']; // <-- ȘTERGEM ASTA
                    final role = member['role'] ?? 'MEMBER';
                    final userName =
                        member['name'] as String; // <-- LUĂM DIRECT
                    final isYou = (userName == widget.currentUsername);
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: Icon(
                          role == 'OWNER' ? Icons.star : Icons.person,
                          color: isYou
                              ? Colors.green
                              : (role == 'OWNER' ? Colors.yellow : Colors.red),
                        ),
                        title: Text(
                          isYou ? "$userName (Tu)" : userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          role,
                          style: TextStyle(
                            color: role == 'OWNER'
                                ? Colors.yellow
                                : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      // Arătăm butonul doar dacă utilizatorul are permisiunea
      floatingActionButton: canAddMembers
          ? FloatingActionButton(
              onPressed: _showAddMemberDialog,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}
