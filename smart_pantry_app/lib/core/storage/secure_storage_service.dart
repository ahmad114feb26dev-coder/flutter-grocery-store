import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  // In-memory cache for instant synchronous access and Web race-condition protection
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;
  static String? _cachedUserData;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {}
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    try {
      _cachedAccessToken = await _storage.read(key: _accessTokenKey);
    } catch (_) {}
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    try {
      _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
    } catch (_) {}
    return _cachedRefreshToken;
  }

  Future<void> saveUserData(String userJson) async {
    _cachedUserData = userJson;
    try {
      await _storage.write(key: _userKey, value: userJson);
    } catch (_) {}
  }

  Future<String?> getUserData() async {
    if (_cachedUserData != null && _cachedUserData!.isNotEmpty) {
      return _cachedUserData;
    }
    try {
      _cachedUserData = await _storage.read(key: _userKey);
    } catch (_) {}
    return _cachedUserData;
  }

  Future<void> deleteUserData() async {
    _cachedUserData = null;
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }

  Future<void> deleteTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUserData = null;
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }
}
