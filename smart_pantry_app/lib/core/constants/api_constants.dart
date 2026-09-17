import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://localhost:5001/api/v1';
    }
    return 'http://10.0.2.2:5001/api/v1';
  }

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
