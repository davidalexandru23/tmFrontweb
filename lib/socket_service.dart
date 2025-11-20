import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:async'; // For StreamController
import 'package:task_manager_app/api_config.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/notification_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket socket;
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  
  // NOU: Stream pentru statusul conexiunii
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  
  // NOU: StreamController pentru mesaje (broadcast ca să poată fi ascultat de mai mulți)
  final StreamController<dynamic> _messageController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messageStream => _messageController.stream;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  // Track joined rooms to re-join on reconnect
  final Set<String> _joinedRooms = {};

  void initSocket() async {
    final token = await _storageService.getAccessToken();
    
    // NOU: Configurare mai robustă
    // Socket.IO connects to the root domain, not the API path
    final socketUrl = "https://tm.davidab.ro"; 
    
    socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setExtraHeaders({'Authorization': 'Bearer $token'})
      .enableForceNew() // Force new connection
      .setReconnectionDelay(1000)
      .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket: ${socket.id}');
      isConnected.value = true;
      
      // Re-join all tracked rooms
      for (final room in _joinedRooms) {
        print('Re-joining room: $room');
        socket.emit('join_room', room);
      }
    });

    socket.onDisconnect((_) {
      print('Disconnected from socket');
      isConnected.value = false;
    });

    socket.onConnectError((data) {
      print('Socket connection error: $data');
      isConnected.value = false;
    });

    // Global listener for messages
    socket.on('receive_message', (data) {
      print('Message received: $data');
      // 1. Add to stream for UI
      _messageController.add(data);
      
      // 2. Show notification (global)
      final senderName = data['sender']?['name'] ?? 'New Message';
      final content = data['content'] ?? 'Sent an image';
      _notificationService.showNotification(senderName, content);
    });

    socket.on('notification', (data) {
      print('Notification received: $data');
      _notificationService.showNotification(
        data['title'] ?? 'Notificare',
        data['body'] ?? '',
      );
    });
  }

  void joinRoom(String room) {
    _joinedRooms.add(room); // Track room
    
    if (socket.connected) {
      print('Joining room: $room');
      socket.emit('join_room', room);
    } else {
      // Dacă nu e conectat, se va face join automat la onConnect datorită _joinedRooms
      print('Queueing join room: $room');
    }
  }

  void sendMessage(String content, String senderId, {String? receiverId, String? workspaceId}) {
    print('Sending message from $senderId to ${receiverId ?? workspaceId}');
    socket.emit('send_message', {
      'content': content,
      'senderId': senderId,
      'receiverId': receiverId,
      'workspaceId': workspaceId,
    });
  }

  // Deprecated: Use messageStream instead
  // void onMessage(Function(dynamic) callback) { ... }

  void onNotification(Function(dynamic) callback) {
    socket.on('notification', callback);
  }

  void dispose() {
    socket.dispose();
    _messageController.close();
  }
}
