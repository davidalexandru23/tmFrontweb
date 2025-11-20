import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/task_details_page.dart';
import 'package:task_manager_app/create_task_page.dart';

class WorkspaceTasksPage extends StatefulWidget {
  final String workspaceId;
  final String workspaceName;
  final String currentUsername;

  const WorkspaceTasksPage({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
    required this.currentUsername,
  });

  @override
  State<WorkspaceTasksPage> createState() => _WorkspaceTasksPageState();
}

class _WorkspaceTasksPageState extends State<WorkspaceTasksPage> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('/tasks/workspace/${widget.workspaceId}');
      if (response.statusCode == 200) {
        setState(() {
          _tasks = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // Handle error
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTaskItem(dynamic task) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task['title'] ?? 'Fără titlu', style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${task['status'] ?? 'UNKNOWN'}', style: const TextStyle(color: Colors.grey)),
            if (task['assignments'] != null && (task['assignments'] as List).isNotEmpty)
              Text(
                'Asignat: ${(task['assignments'][0]['assignee']['name'])}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
        onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsPage(
                taskId: task['id'],
                currentUsername: widget.currentUsername,
              ),
            ),
          ).then((_) => _fetchTasks());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Sarcini: ${widget.workspaceName}',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _tasks.isEmpty
              ? const Center(child: Text('Nu există sarcini în acest grup.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) => _buildTaskItem(_tasks[index]),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTaskPage(), // We might want to pre-select workspace
            ),
          ).then((_) => _fetchTasks());
        },
      ),
    );
  }
}
