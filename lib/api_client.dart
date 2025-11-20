import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:task_manager_app/api_config.dart';
import 'package:task_manager_app/storage_service.dart';

/// 1) Interceptor care atașează Authorization + Content-Type
class AuthInterceptor implements InterceptorContract {
  final StorageService _storage = StorageService();

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Content-Type'] = 'application/json';
    } catch (_) {}
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    return response;
  }

  @override
  Future<bool> shouldInterceptRequest() async => true;

  @override
  Future<bool> shouldInterceptResponse() async => true;
}

/// 2) RetryPolicy: la 401 face refresh și cere retry automat
class ExpiredTokenRetryPolicy extends RetryPolicy {
  final StorageService _storage = StorageService();

  @override
  int get maxRetryAttempts => 1;

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (response.statusCode == 401) {
      try {
        final refreshToken = await _storage.getRefreshToken();
        final currentUsername = await _storage.getUsername();

        if (refreshToken == null ||
            refreshToken.isEmpty ||
            currentUsername == null) {
          return false;
        }

        final refreshResp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );

        if (refreshResp.statusCode == 200) {
          final m = jsonDecode(refreshResp.body) as Map<String, dynamic>;
          final access = m['accessToken'] as String?;
          final refresh = m['refreshToken'] as String?;
          if (access != null && refresh != null) {
            await _storage.saveAuthData(access, refresh, currentUsername);
            return true;
          }
        } else {
          await _storage.clearAuthData();
        }
      } catch (_) {
        await _storage.clearAuthData();
      }
    }
    return false;
  }
}

/// 3) Client centralizat
class ApiClient {
  final InterceptedHttp client;

  ApiClient()
    : client = InterceptedHttp.build(
        interceptors: [AuthInterceptor()],
        retryPolicy: ExpiredTokenRetryPolicy(),
      );


  Future<http.Response> get(
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) {
    // Construim Uri-ul de bază
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');

    // Adăugăm query parameters dacă există
    // Funcția .replace() se ocupă automat de URL encoding (ex: spațiu devine %20)
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    return client.get(uri);
  }
 

  Future<http.Response> post(String path, dynamic body) {
    return client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String path, dynamic body) {
    return client.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      body: jsonEncode(body),
    );
  }
}
