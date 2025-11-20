import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:task_manager_app/api_config.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/notification_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket socket;
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void initSocket() async {
    final token = await _storageService.getAccessToken();
    
    socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'}
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket');
    });

    socket.onDisconnect((_) {
      print('Disconnected from socket');
    });

    socket.on('notification', (data) {
      _notificationService.showNotification(
        data['title'] ?? 'Notificare',
        data['body'] ?? '',
      );
    });
  }

  void joinRoom(String room) {
    socket.emit('join_room', room);
  }

  void sendMessage(String content, String senderId, {String? receiverId, String? workspaceId}) {
    socket.emit('send_message', {
      'content': content,
      'senderId': senderId,
      'receiverId': receiverId,
      'workspaceId': workspaceId,
    });
  }

  void onMessage(Function(dynamic) callback) {
    socket.on('receive_message', callback);
  }

  void onNotification(Function(dynamic) callback) {
    socket.on('notification', callback);
  }

  void dispose() {
    socket.dispose();
  }
}
