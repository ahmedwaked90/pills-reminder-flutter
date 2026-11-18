import 'package:dio/dio.dart';
import 'package:pills_reminder/core/config/api_config.dart';
import 'package:pills_reminder/features/auth/data/secure_token_storage.dart';

/// Thin Dio wrapper with:
///  - base URL from [ApiConfig]
///  - `Authorization: Bearer <token>` injected per request
///  - JSON content-type and reasonable timeouts
class ApiClient {
  ApiClient(this._tokenStorage) : dio = _buildDio() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
      ),
    );
  }

  final SecureTokenStorage _tokenStorage;
  final Dio dio;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {'Content-Type': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
      ),
    );
  }
}
