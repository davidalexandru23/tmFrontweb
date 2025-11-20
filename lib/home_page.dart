import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/login_page.dart';
import 'dart:convert';
import 'package:task_manager_app/group_details_page.dart';
import 'package:task_manager_app/create_task_page.dart';
import 'package:task_manager_app/task_details_page.dart';
import 'package:task_manager_app/calendar_page.dart';
import 'package:task_manager_app/conversations_page.dart';
import 'package:task_manager_app/map_page.dart';
import 'package:task_manager_app/notification_service.dart';
import 'package:task_manager_app/socket_service.dart';
import 'package:task_manager_app/account_settings_page.dart';
import 'package:task_manager_app/workspaces_page.dart';

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  final ApiClient _apiClient = ApiClient();
  final NotificationService _notificationService = NotificationService();
  final SocketService _socketService = SocketService();

  List<dynamic> _workspaces = [];
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initServices();
    _fetchData();
  }

  Future<void> _initServices() async {
    await _notificationService.init();
    _socketService.initSocket();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch Workspaces
      final workspacesResponse = await _apiClient.get('/workspaces');
      if (workspacesResponse.statusCode == 200) {
        setState(() {
          _workspaces = jsonDecode(workspacesResponse.body);
        });
      }

      // 2. Fetch Tasks
      final tasksResponse = await _apiClient.get('/tasks');
      if (tasksResponse.statusCode == 200) {
        setState(() {
          _tasks = jsonDecode(tasksResponse.body);
        });
      }
      
      // Get User ID
      final userResponse = await _apiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
         final user = jsonDecode(userResponse.body);
         _userId = user['id'];
         _socketService.joinRoom(_userId!);
      }

    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await _storageService.clearAuthData();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'CENTRUL DE COMANDĂ',
              style: GoogleFonts.robotoSlab(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
            Text(
              'BINE AI VENIT, ${widget.username.toUpperCase()}',
              style: GoogleFonts.robotoSlab(
                color: Colors.white,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.red),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navigation Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavButton(Icons.calendar_today, 'Calendar', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()));
                      }),
                      _buildNavButton(Icons.chat, 'Chat', () {
                        if (_userId != null) {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationsPage(currentUserId: _userId!)));
                        }
                      }),
                      _buildNavButton(Icons.group, 'Grupuri', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => WorkspacesPage(currentUsername: widget.username)));
                      }),
                      _buildNavButton(Icons.map, 'Harta', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage()));
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Workspaces Section
                  Text(
                    'GRUPURI OPERATIVE',
                    style: GoogleFonts.robotoSlab(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _workspaces.length,
                    itemBuilder: (context, index) {
                      final workspace = _workspaces[index];
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(workspace['name'], style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupDetailsPage(
                                  workspaceId: workspace['id'],
                                  currentUsername: widget.username,
                                ),
                              ),
                            ).then((_) => _fetchData());
                          },
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tasks Section
                  Text(
                    'SARCINI CURENTE',
                    style: GoogleFonts.robotoSlab(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                   ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(task['title'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(task['status'], style: const TextStyle(color: Colors.grey)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
                          onTap: () {
                             Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailsPage(
                                  taskId: task['id'],
                                  currentUsername: widget.username,
                                ),
                              ),
                            ).then((_) => _fetchData());
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateTaskPage()),
          ).then((_) => _fetchData());
        },
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.red, size: 30),
          onPressed: onTap,
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
