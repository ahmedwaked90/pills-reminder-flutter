import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pills_reminder/core/config/api_config.dart';
import 'package:pills_reminder/core/network/api_client.dart';
import 'package:pills_reminder/features/auth/data/secure_token_storage.dart';
import 'package:pills_reminder/features/auth/domain/entities/auth_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureTokenStorage tokenStorage,
    GoogleSignIn? googleSignIn,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage,
       _googleSignIn = googleSignIn ??
           GoogleSignIn(
             scopes: const ['email', 'openid', 'profile'],
             serverClientId: ApiConfig.googleServerClientId.isEmpty
                 ? null
                 : ApiConfig.googleServerClientId,
           );

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;
  final GoogleSignIn _googleSignIn;

  Future<String?> currentToken() => _tokenStorage.read();

  /// Pops the Google Sign-In sheet, obtains an ID token, exchanges it
  /// with the backend for a Sanctum token, stores the token securely,
  /// and returns the signed-in user.
  Future<AuthUser> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw AuthException('Sign-in cancelled');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException(
        'Google did not return an ID token. Did you set GOOGLE_SERVER_CLIENT_ID '
        'to the Web OAuth client ID at build time?',
      );
    }

    final deviceName = _deviceName();

    try {
      final resp = await _apiClient.dio.post(
        '/auth/google',
        data: {'id_token': idToken, 'device_name': deviceName},
      );
      if (resp.statusCode != 200 || resp.data is! Map) {
        throw AuthException(
          'Backend rejected sign-in (${resp.statusCode}): ${resp.data}',
        );
      }
      final data = Map<String, dynamic>.from(resp.data as Map);
      final token = data['token'] as String?;
      final userJson = data['user'] as Map?;
      if (token == null || userJson == null) {
        throw AuthException('Malformed sign-in response from backend');
      }
      await _tokenStorage.write(token);
      return AuthUser.fromJson(Map<String, dynamic>.from(userJson));
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<AuthUser?> fetchMe() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;
    try {
      final resp = await _apiClient.dio.get('/auth/me');
      if (resp.statusCode == 401) {
        await _tokenStorage.clear();
        return null;
      }
      if (resp.statusCode != 200 || resp.data is! Map) return null;
      final data = Map<String, dynamic>.from(resp.data as Map);
      final userJson = data['user'] as Map?;
      if (userJson == null) return null;
      return AuthUser.fromJson(Map<String, dynamic>.from(userJson));
    } on DioException {
      // Offline or server down — stay signed in locally; sync will retry.
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } on DioException {
      // Best-effort; still clear local state below.
    }
    await _tokenStorage.clear();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  String _deviceName() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'mobile';
  }

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (status != null) return 'HTTP $status — $body';
    return e.message ?? 'Network error';
  }
}
