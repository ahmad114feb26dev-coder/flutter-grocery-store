import 'package:flutter/foundation.dart';

/// Single place for backend URL. All HTTP + Socket.IO in lib use this file.
class ApiConstants {
  static const String defaultUrl = 'http://72.62.246.243:3074/api/v1';
  static String? _customUrl;

  static void setBaseUrl(String url) {
    String clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!clean.endsWith('/api/v1')) {
      clean = '$clean/api/v1';
    }
    _customUrl = clean;
  }

  static String get baseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty) {
      return _customUrl!;
    }
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultUrl;
  }

  /// Socket.IO server (same host as API, without /api/v1).
  static String get socketUrl => baseUrl.replaceAll('/api/v1', '');

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String inventory = '/inventory';
  static const String recipeSuggestions = '/recipes/suggestions';
  static const String shoppingList = '/shopping-list';
  static const String users = '/users';
}
