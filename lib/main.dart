import 'package:flutter/material.dart';
import 'package:task_manager_app/home_page.dart';
import 'package:task_manager_app/login_page.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/api_client.dart'; // Importăm noul client

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
      home: _AppInitializer(), // Folosim "splash screen-ul" logic
    );
  }
}

// Widget-ul care decide unde să trimită utilizatorul la pornire
class _AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Verificăm dacă avem token-uri ȘI username
    final refreshToken = await _storageService.getRefreshToken();
    final username = await _storageService.getUsername();

    if (refreshToken == null || username == null) {
      // Nu e logat, mergem la Login
      _navigateTo(const LoginPage());
      return;
    }

    // Avem token-uri. Încercăm un apel API real ca să testăm token-ul.
    // ApiClient (cu RetryPolicy) va face refresh automat dacă e nevoie.
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/logs'); // Un apel "ușor"

      if (response.statusCode == 200) {
        // Token-ul e valid (sau a fost reînnoit), mergem direct la HomePage
        _navigateTo(HomePage(username: username));
      } else {
        // Ceva a eșuat (ex: refresh-ul a dat eroare 403, serverul a picat)
        await _storageService.clearAuthData();
        _navigateTo(const LoginPage());
      }
    } catch (e) {
      // Fără rețea, etc.
      print("Eroare la pornire: $e");
      // Mergem la login, deși am putea merge la home în mod "offline"
      _navigateTo(const LoginPage());
    }
  }

  void _navigateTo(Widget page) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un splash screen simplu
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.red)),
    );
  }
}
