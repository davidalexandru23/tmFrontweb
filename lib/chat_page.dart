import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_manager_app/socket_service.dart';
import 'package:task_manager_app/api_client.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final bool isWorkspace;

  const ChatPage({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    this.isWorkspace = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final SocketService _socketService = SocketService();
  final ApiClient _apiClient = ApiClient();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  
  // NOU: Ascultăm statusul conexiunii
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _socketService.initSocket();
    
    // Ascultăm schimbările de conexiune
    _socketService.isConnected.addListener(_updateConnectionStatus);
    _updateConnectionStatus(); // Setăm starea inițială

    // Ne asigurăm că suntem în cameră
    _socketService.joinRoom(widget.currentUserId);
    
    _loadMessageHistory();

    _socketService.onMessage((data) {
      if (mounted) {
        print('ChatPage received message: $data');
        // Only add if it's for this conversation
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        
        // Verificăm dacă mesajul aparține acestei conversații
        // 1. Mesaj primit de la interlocutor
        // 2. Mesaj trimis de mine (dacă vine prin socket ca confirmare, deși îl adăugăm și local)
        // Verificăm dacă mesajul aparține acestei conversații
        // 1. Mesaj primit de la interlocutor
        // 2. Ignorăm mesajele trimise de mine (le-am adăugat deja optimisitic)
        if (senderId == widget.receiverId && receiverId == widget.currentUserId) {
          setState(() {
            _messages.add(data);
          });
          _scrollToBottom();
        }
      }
    });
  }

  void _updateConnectionStatus() {
    if (mounted) {
      setState(() {
        _isConnected = _socketService.isConnected.value;
      });
    }
  }

  @override
  void dispose() {
    _socketService.isConnected.removeListener(_updateConnectionStatus);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessageHistory() async {
    try {
      // Determine endpoint based on context (direct or workspace)
      // We need to know if this is a workspace chat.
      // Currently ChatPage is designed for direct messages (receiverId, receiverName).
      // We should add a `workspaceId` parameter or similar.
      // But wait, ChatPage constructor signature:
      // final String currentUserId;
      // final String receiverId;
      // final String receiverName;
      
      // If receiverId is a workspaceId, we use workspace endpoint?
      // Or we add a new parameter `isWorkspace`.
      // Let's check how it's called.
      // In HomePage: Navigator.push(..., ConversationsPage...) -> ChatPage
      // In GroupDetailsPage? No chat button there yet.
      
      // I need to update ChatPage to accept `isWorkspace` or `workspaceId`.
      // Let's assume if I pass `workspaceId` as `receiverId`, I need a flag.
      
      String endpoint = '/messages/direct/${widget.receiverId}';
      if (widget.isWorkspace) {
        endpoint = '/messages/workspace/${widget.receiverId}';
      }

      final response = await _apiClient.get(endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        setState(() {
          _messages.clear();
          _messages.addAll(history.map((m) => m as Map<String, dynamic>));
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        print('Error loading history: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Exception loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage({String? imagePath}) {
    if (_messageController.text.trim().isEmpty && imagePath == null) return;

    final content = _messageController.text;
    
    // Create message object for local UI
    final localMessage = {
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'sender': {'id': widget.currentUserId, 'name': 'Tu'},
      if (imagePath != null) 'localImagePath': imagePath,
    };

    // Add to UI immediately (optimistic update)
    setState(() {
      _messages.add(localMessage);
    });
    _scrollToBottom();

    // Send via socket (only text content, not image path)
    if (widget.isWorkspace) {
       _socketService.sendMessage(
        content,
        widget.currentUserId,
        workspaceId: widget.receiverId,
      );
    } else {
      _socketService.sendMessage(
        content,
        widget.currentUserId,
        receiverId: widget.receiverId,
      );
    }

    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      // Save image to app's document directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final savedPath = '${directory.path}/$fileName';
      
      await File(pickedFile.path).copy(savedPath);
      
      // Send message with local image path
      _sendMessage(imagePath: savedPath);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: GoogleFonts.robotoSlab(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Conectat' : 'Deconectat',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] == widget.currentUserId;
                      final localImagePath = message['localImagePath'] as String?;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.red[900] : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (localImagePath != null && File(localImagePath).existsSync())
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(localImagePath),
                                    width: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (message['content'] != null && message['content'].isNotEmpty)
                                Text(
                                  message['content'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.red),
                        onPressed: _pickAndSendImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.red,
                          decoration: InputDecoration(
                            hintText: 'Scrie un mesaj...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.red),
                        onPressed: () => _sendMessage(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
