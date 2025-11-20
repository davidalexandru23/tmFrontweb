import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/widgets/delegation_chain_widget.dart';

// NOU: Un model simplu pentru a ține datele combinate
class _TaskDetailsData {
  final Map<String, dynamic> task;
  final Map<String, dynamic> workspace;
  _TaskDetailsData(this.task, this.workspace);
}

class TaskDetailsPage extends StatefulWidget {
  final String taskId;
  final String currentUsername;
  final ApiClient apiClient = ApiClient();

  TaskDetailsPage({
    super.key,
    required this.taskId,
    required this.currentUsername,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  // NOU: Acest Future va ține ambele obiecte
  late Future<_TaskDetailsData> _detailsFuture;

  // Stări de încărcare pentru butoane
  bool _isUpdatingStatus = false;
  bool _isDelegating = false;
  bool _isAddingSubtask = false; // NOU

  // Controlere pentru noul dialog de sub-sarcină
  final _subtaskTitleController = TextEditingController();
  String? _selectedSubtaskAssigneeId;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchTaskAndWorkspaceDetails();
  }

  @override
  void dispose() {
    _subtaskTitleController.dispose();
    super.dispose();
  }

  // NOU: Funcție care încarcă TOT ce e necesar pentru pagină
  Future<_TaskDetailsData> _fetchTaskAndWorkspaceDetails() async {
    try {
      // 1. Luăm sarcina
      final taskResponse = await widget.apiClient.get(
        '/tasks/${widget.taskId}',
      );
      if (taskResponse.statusCode != 200) {
        throw Exception('Eroare la încărcarea sarcinii: ${taskResponse.body}');
      }
      final taskData = jsonDecode(taskResponse.body);
      final workspaceId = taskData['workspaceId'];

      // 2. Luăm detaliile grupului (pentru a afla rolul și membrii)
      final workspaceResponse = await widget.apiClient.get(
        '/workspaces/$workspaceId',
      );
      if (workspaceResponse.statusCode != 200) {
        throw Exception(
          'Eroare la încărcarea grupului: ${workspaceResponse.body}',
        );
      }
      final workspaceData = jsonDecode(workspaceResponse.body);

      // 3. Returnăm ambele
      return _TaskDetailsData(taskData, workspaceData);
    } catch (e) {
      throw Exception('Eroare rețea: $e');
    }
  }

  // NOU: Funcție de reîmprospătare
  void _refreshDetails() {
    setState(() {
      _detailsFuture = _fetchTaskAndWorkspaceDetails();
    });
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

  // --- Funcția pentru Finalizare Sarcină ---
  Future<void> _handleUpdateStatus(String newStatus) async {
    setState(() {
      _isUpdatingStatus = true;
    });
    try {
      final response = await widget.apiClient.patch(
        '/tasks/${widget.taskId}/status',
        {'status': newStatus},
      );
      if (response.statusCode == 200) {
        _showSuccess('Sarcina a fost actualizată!');
        _refreshDetails(); // Reîmprospătăm
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError('Eroare: $error');
      }
    } catch (e) {
      _showError('Eroare rețea: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // În lib/task_details_page.dart

  // --- Funcțiile pentru Delegare ---

  // Pasul 1: Afișează dialogul (VERSIUNEA CORECTATĂ)
  Future<void> _showDelegateDialog(
    List<dynamic> members,
    List<String> currentChainIds,
  ) async {
    // NOU: Filtrare corectă pe structura "plată"
    final eligibleMembers = members.where((member) {
      // Verificare de siguranță
      if (member == null || member['id'] == null) return false;
      return !currentChainIds.contains(member['id']); // <-- CORECTAT
    }).toList();

    if (eligibleMembers.isEmpty) {
      _showError("Nu mai sunt membri disponibili pentru delegare.");
      return;
    }

    // 3. Afișăm dialogul
    final String? selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            "Deleagă Sarcina",
            style: GoogleFonts.robotoSlab(color: Colors.red),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: eligibleMembers.length,
              itemBuilder: (context, index) {
                final member = eligibleMembers[index];

                // NOU: Citim structura "plată"
                final String? memberId = member['id'] as String?;
                final String memberName =
                    member['name'] as String? ?? 'Nume invalid';

                if (memberId == null) return const SizedBox.shrink();

                return ListTile(
                  leading: const Icon(Icons.person, color: Colors.red),
                  title: Text(
                    memberName,
                    style: const TextStyle(color: Colors.white),
                  ), // <-- CORECTAT
                  onTap: () {
                    // Când e selectat, închide dialogul și returnează ID-ul
                    Navigator.of(dialogContext).pop(memberId); // <-- CORECTAT
                  },
                );
              },
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

    // 4. Dacă un utilizator a fost selectat, apelăm funcția de delegare
    if (selectedId != null) {
      await _handleDelegate(selectedId);
    }
  }

  // ... (restul fișierului rămâne neschimbat) ...
  Future<void> _handleDelegate(String newAssigneeId) async {
    setState(() {
      _isDelegating = true;
    });
    try {
      final response = await widget.apiClient.post(
        '/tasks/${widget.taskId}/delegate',
        {'newAssigneeId': newAssigneeId},
      );
      if (response.statusCode == 200) {
        _showSuccess("Sarcină delegată cu succes!");
        _refreshDetails(); // Reîmprospătăm
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError('Eroare delegare: $error');
      }
    } catch (e) {
      _showError('Eroare rețea: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDelegating = false;
        });
      }
    }
  }

  // --- NOU: Funcțiile pentru Adăugare Sub-sarcină ---

  // Pasul 1: Afișează dialogul
  Future<void> _showAddSubtaskDialog(List<dynamic> members) async {
    _subtaskTitleController.clear();
    _selectedSubtaskAssigneeId = null;

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        // Folosim StatefulBuilder pentru a actualiza starea dropdown-ului
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                "Adaugă Sub-sarcină",
                style: GoogleFonts.robotoSlab(color: Colors.red),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _subtaskTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Titlu sub-sarcină",
                      labelStyle: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubtaskAssigneeId,
                    hint: const Text(
                      'Alocă unui membru',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    items: members
                        .map((member) {
                          // Verificare de siguranță pe structura plată
                          if (member['id'] == null || member['name'] == null) {
                            return null;
                          }

                          final userId = member['id'] as String;
                          final userName = member['name'] as String;

                          return DropdownMenuItem<String>(
                            value: userId,
                            child: Text(userName),
                          );
                        })
                        .whereType<DropdownMenuItem<String>>()
                        .toList(), // Filtrăm null-urile
                    onChanged: (value) {
                      setStateInDialog(() {
                        _selectedSubtaskAssigneeId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    "Anulează",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  // NOU: Aici este corecția
                  onPressed:
                      _subtaskTitleController.text.isNotEmpty &&
                          _selectedSubtaskAssigneeId != null
                      ? () {
                          // Dacă e valid, returnăm true și închidem
                          Navigator.of(dialogContext).pop(true);
                        }
                      : null, // Dezactivăm butonul dacă datele lipsesc
                  child: const Text("Salvează"),
                ),
              ],
            );
          },
        );
      },
    );

    // Pasul 2: Dacă utilizatorul a apăsat "Salvează", creăm
    if (shouldCreate == true) {
      await _handleCreateSubtask();
    }
  }

  // Pasul 2: Trimite cererea API
  Future<void> _handleCreateSubtask() async {
    setState(() {
      _isAddingSubtask = true;
    });
    try {
      final body = {
        'title': _subtaskTitleController.text,
        'assigneeId': _selectedSubtaskAssigneeId,
        // (Poți adăuga descriere și dueDate dacă vrei)
      };

      final response = await widget.apiClient.post(
        '/tasks/${widget.taskId}/subtasks',
        body,
      );

      if (response.statusCode == 201) {
        _showSuccess("Sub-sarcină creată!");
        _refreshDetails(); // Reîmprospătăm
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showError('Eroare: $error');
      }
    } catch (e) {
      _showError('Eroare rețea: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAddingSubtask = false;
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
          'Detalii Sarcină',
          style: GoogleFonts.robotoSlab(color: Colors.red),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: FutureBuilder<_TaskDetailsData>(
        // NOU: Folosim modelul combinat
        future: _detailsFuture,
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
                'Sarcină negăsită.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Avem date!
          final task = snapshot.data!.task;
          final workspace = snapshot.data!.workspace;

          final title = task['title'] ?? 'Fără Titlu';
          final description = task['description'] ?? 'Fără descriere.';
          final dueDate = task['dueDate']?.substring(0, 10) ?? 'N/A';
          final status = task['status'] ?? 'TODO';
          final isDone = status == 'DONE';

          final chainIds = (task['delegationChain'] as List? ?? [])
              .map((user) => (user['id'] ?? '') as String)
              .toList();
          final chainNames = (task['delegationChain'] as List? ?? [])
              .map((user) => (user['name'] ?? '??') as String)
              .toList();

          final subTasks = (task['subTasks'] as List? ?? []);
          // ...
          final allMembers = (workspace['members'] as List? ?? []);

          // NOU: Aflăm rolul utilizatorului (varianta corectată)
          String userRole = 'MEMBER';
          final myMemberInfo = allMembers.firstWhere((m) {
            // Verificare de siguranță
            if (m == null || m['name'] == null) return false;
            return m['name'] == widget.currentUsername; // <-- CORECT
          }, orElse: () => null);
          if (myMemberInfo != null) {
            userRole =
                myMemberInfo['role'] as String? ??
                'MEMBER'; // Adăugăm siguranță
          }
          final bool canAddSubtasks =
              (userRole == 'OWNER' || userRole == 'LEADER');
          // ...

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lanțul de delegare
                DelegationChainWidget(
                  chain: chainNames,
                  currentUsername: widget.currentUsername,
                ),
                const SizedBox(height: 16),

                // Titlul
                Text(
                  title,
                  style: GoogleFonts.robotoSlab(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Detalii (Termen, Status)
                Text(
                  'Termen: $dueDate\nStatus: $status',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const Divider(color: Colors.grey, height: 32),

                // Descriere
                Text(
                  'Descriere:',
                  style: GoogleFonts.robotoSlab(
                    color: Colors.red,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const Divider(color: Colors.grey, height: 32),

                // Sub-Sarcini
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sub-Sarcini',
                      style: GoogleFonts.robotoSlab(
                        color: Colors.red,
                        fontSize: 18,
                      ),
                    ),
                    // NOU: Butonul de adăugare sub-sarcină (doar pentru lideri)
                    if (canAddSubtasks)
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.red),
                        onPressed: _isAddingSubtask
                            ? null
                            : () => _showAddSubtaskDialog(allMembers),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isAddingSubtask)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Colors.red),
                    ),
                  ),
                if (subTasks.isEmpty)
                  const Text(
                    'Această sarcină nu are sub-sarcini.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ListView.builder(
                    // ... (codul ListView.builder rămâne neschimbat) ...
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subTasks.length,
                    itemBuilder: (ctx, index) {
                      final subTask = subTasks[index];
                      final isSubTaskDone = subTask['status'] == 'DONE';
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: Icon(
                            isSubTaskDone
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSubTaskDone ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            subTask['title'] ?? 'Sub-sarcină',
                            style: TextStyle(
                              color: isSubTaskDone ? Colors.grey : Colors.white,
                              decoration: isSubTaskDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),

                // --- Butoanele de Acțiune ---

                // Butonul de Finalizare
                if (!isDone)
                  ElevatedButton(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _handleUpdateStatus('DONE'),
                    child: _isUpdatingStatus
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Marchează ca Finalizat'),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _handleUpdateStatus('IN_PROGRESS'),
                    child: _isUpdatingStatus
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Reactivează Sarcina'),
                  ),
                const SizedBox(height: 8),

                // Butonul de Delegare
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: _isUpdatingStatus || _isDelegating
                      ? null
                      : () => _showDelegateDialog(allMembers, chainIds),
                  child: _isDelegating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Deleagă Sarcina'),
                ),
                
                const SizedBox(height: 24),
                
                // NOU: Butoane de Editare și Ștergere (Doar pentru Owner/Leader)
                if (userRole == 'OWNER' || userRole == 'LEADER') ...[
                  const Divider(color: Colors.grey),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        label: const Text('Editează', style: TextStyle(color: Colors.blue)),
                        onPressed: () => _showEditTaskDialog(title, description),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Șterge', style: TextStyle(color: Colors.red)),
                        onPressed: () => _confirmDeleteTask(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // NOU: Funcții pentru Editare și Ștergere

  Future<void> _confirmDeleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Șterge Sarcina', style: TextStyle(color: Colors.red)),
        content: const Text('Ești sigur? Această acțiune este ireversibilă.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulează')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Șterge', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await widget.apiClient.delete('/tasks/${widget.taskId}');
        if (response.statusCode == 204) {
          Navigator.pop(context); // Close page
        } else {
          _showError('Eroare la ștergere: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Eroare: $e');
      }
    }
  }

  Future<void> _showEditTaskDialog(String currentTitle, String currentDescription) async {
    final titleController = TextEditingController(text: currentTitle);
    final descController = TextEditingController(text: currentDescription);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Editează Sarcina', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Titlu', labelStyle: TextStyle(color: Colors.grey)),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Descriere', labelStyle: TextStyle(color: Colors.grey)),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulează')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final response = await widget.apiClient.put(
          '/tasks/${widget.taskId}',
          {
            'title': titleController.text,
            'description': descController.text,
          },
        );
        
        if (response.statusCode == 200) {
          _showSuccess('Sarcină actualizată');
          _refreshDetails();
        } else {
           _showError('Eroare la actualizare: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Eroare: $e');
      }
    }
  }
}
