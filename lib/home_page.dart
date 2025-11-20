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
  List<dynamic> _createdTasks = []; // NOU
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

      // 2. Fetch Assigned Tasks
      final tasksResponse = await _apiClient.get('/tasks');
      if (tasksResponse.statusCode == 200) {
        setState(() {
          _tasks = jsonDecode(tasksResponse.body);
        });
      }

      // 3. Fetch Created Tasks (NOU)
      // Încercăm să luăm task-urile create de user.
      // Dacă API-ul nu suportă filtrare directă, momentan lăsăm lista goală sau
      // presupunem că /tasks returnează tot și filtrăm noi (dacă am avea ID-ul userului).
      // Totuși, pentru a fi safe, facem un request separat dacă există endpoint.
      // Presupunem un endpoint /tasks/created sau filtrare.
      // Voi încerca să filtrez local dacă am user ID, altfel fac request.
      
      // Get User ID first
      final userResponse = await _apiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
         final user = jsonDecode(userResponse.body);
         _userId = user['id'];
         _socketService.joinRoom(_userId!);
         
         // Acum că avem ID-ul, putem încerca să luăm task-urile create
         // Voi încerca un endpoint specific, dacă nu merge, aia e.
         try {
           final createdResponse = await _apiClient.get('/tasks?filter=delegated');
           if (createdResponse.statusCode == 200) {
             setState(() {
               _createdTasks = jsonDecode(createdResponse.body);
             });
           } else {
             // Fallback: poate endpoint-ul e altul, de ex /tasks/created
             final createdResponse2 = await _apiClient.get('/tasks/created');
             if (createdResponse2.statusCode == 200) {
                setState(() {
                  _createdTasks = jsonDecode(createdResponse2.body);
                });
             }
           }
         } catch (e) {
           print('Error fetching created tasks: $e');
         }
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
  
  // NOU: Helper pentru construirea unui item de task
  Widget _buildTaskItem(dynamic task) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task['title'] ?? 'Fără titlu', style: const TextStyle(color: Colors.white)),
        subtitle: Text(task['status'] ?? 'UNKNOWN', style: const TextStyle(color: Colors.grey)),
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
                                  currentUserId: _userId ?? '',
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
                    'SARCINI',
                    style: GoogleFonts.robotoSlab(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // NOU: Tab-uri pentru sarcini
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          indicatorColor: Colors.red,
                          labelColor: Colors.red,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(text: 'Primite'),
                            Tab(text: 'Create de mine'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 300, // Înălțime fixă pentru listă (sau folosim shrinkWrap cu physics)
                          child: TabBarView(
                            children: [
                              // Tab 1: Sarcini Primite
                              _tasks.isEmpty
                                  ? const Center(child: Text('Nu ai sarcini primite.', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: _tasks.length,
                                      itemBuilder: (context, index) => _buildTaskItem(_tasks[index]),
                                    ),
                                    
                              // Tab 2: Sarcini Create de mine
                              _createdTasks.isEmpty
                                  ? const Center(child: Text('Nu ai creat sarcini pentru alții.', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: _createdTasks.length,
                                      itemBuilder: (context, index) => _buildTaskItem(_createdTasks[index]),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
