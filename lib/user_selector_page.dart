import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';

class UserSelectorPage extends StatefulWidget {
  const UserSelectorPage({super.key});

  @override
  State<UserSelectorPage> createState() => _UserSelectorPageState();
}

class _UserSelectorPageState extends State<UserSelectorPage> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get('/users', {'q': query});
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Selectează Utilizator',
          style: GoogleFonts.robotoSlab(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.red,
              decoration: InputDecoration(
                hintText: 'Caută după nume sau email...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: const Icon(Icons.search, color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'Caută utilizatori pentru a începe o conversație',
                          style: GoogleFonts.robotoSlab(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return Card(
                            color: Colors.grey[900],
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Text(
                                  user['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user['name'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                user['email'],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onTap: () {
                                Navigator.of(context).pop(user);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
