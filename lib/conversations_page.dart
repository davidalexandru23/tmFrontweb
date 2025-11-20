import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/chat_page.dart';
import 'package:task_manager_app/user_selector_page.dart';

class ConversationsPage extends StatefulWidget {
  final String currentUserId;

  const ConversationsPage({super.key, required this.currentUserId});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final response = await _apiClient.get('/messages/conversations');
      if (response.statusCode == 200) {
        setState(() {
          _conversations = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startNewConversation() async {
    final selectedUser = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectorPage()),
    );

    if (selectedUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            currentUserId: widget.currentUserId,
            receiverId: selectedUser['id'],
            receiverName: selectedUser['name'],
          ),
        ),
      ).then((_) => _fetchConversations());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'COMUNICAȚII SECRETE',
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
            icon: const Icon(Icons.add_comment, color: Colors.red),
            onPressed: _startNewConversation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Nu există conversații',
                        style: GoogleFonts.robotoSlab(color: Colors.grey, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _startNewConversation,
                        icon: const Icon(Icons.add),
                        label: const Text('Conversație nouă'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    final user = conversation['user'];
                    final lastMessage = conversation['lastMessage'];

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Text(
                            user['name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          user['name'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          lastMessage['content'],
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                currentUserId: widget.currentUserId,
                                receiverId: user['id'],
                                receiverName: user['name'],
                              ),
                            ),
                          ).then((_) => _fetchConversations());
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
