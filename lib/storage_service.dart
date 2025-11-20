import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _usernameKey = 'username'; // NOU

  // NOU: Salvăm totul
  Future<void> saveAuthData(
    String accessToken,
    String refreshToken,
    String username,
  ) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _usernameKey, value: username); // NOU
  }

  // NOU: Ștergem totul
  Future<void> clearAuthData() async {
    await _storage.deleteAll();
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> getUsername() => _storage.read(key: _usernameKey); // NOU
}
