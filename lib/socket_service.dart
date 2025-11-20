import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
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

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void initSocket() async {
    final token = await _storageService.getAccessToken();
    
    // NOU: Configurare mai robustă
    // Socket.IO connects to the root domain, not the API path
    final socketUrl = "https://tm.davidab.ro"; 
    
    socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setExtraHeaders({'Authorization': 'Bearer $token'})
      .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket: ${socket.id}');
      isConnected.value = true;
    });

    socket.onDisconnect((_) {
      print('Disconnected from socket');
      isConnected.value = false;
    });

    socket.onConnectError((data) {
      print('Socket connection error: $data');
      isConnected.value = false;
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
    if (socket.connected) {
      print('Joining room: $room');
      socket.emit('join_room', room);
    } else {
      // Dacă nu e conectat, așteptăm conectarea
      socket.onConnect((_) {
        print('Joining room (delayed): $room');
        socket.emit('join_room', room);
      });
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

  void onMessage(Function(dynamic) callback) {
    // Eliminăm listenerii vechi pentru a evita duplicatele
    socket.off('receive_message');
    socket.on('receive_message', (data) {
      print('Message received: $data');
      callback(data);
    });
  }

  void onNotification(Function(dynamic) callback) {
    socket.on('notification', callback);
  }

  void dispose() {
    socket.dispose();
  }
}
