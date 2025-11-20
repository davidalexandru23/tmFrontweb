import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/create_workspace_page.dart';
import 'package:task_manager_app/group_details_page.dart';

class WorkspacesPage extends StatefulWidget {
  final String currentUsername;

  const WorkspacesPage({super.key, required this.currentUsername});

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _workspaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkspaces();
  }

  Future<void> _fetchWorkspaces() async {
    try {
      final response = await _apiClient.get('/workspaces');
      if (response.statusCode == 200) {
        setState(() {
          _workspaces = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createWorkspace() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateWorkspacePage()),
    );

    if (result == true) {
      _fetchWorkspaces(); // Refresh list
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'GRUPURI',
          style: GoogleFonts.robotoSlab(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.red),
            onPressed: _createWorkspace,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _workspaces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Nu ești membru în niciun grup',
                        style: GoogleFonts.robotoSlab(color: Colors.grey, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _createWorkspace,
                        icon: const Icon(Icons.add),
                        label: const Text('Creează Grup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workspaces.length,
                  itemBuilder: (context, index) {
                    final workspace = _workspaces[index];
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Text(
                            workspace['name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          workspace['name'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupDetailsPage(
                                workspaceId: workspace['id'],
                                currentUsername: widget.currentUsername,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
