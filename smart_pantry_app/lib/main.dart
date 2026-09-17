import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/animations/scroll_reveal.dart';
import 'core/constants/api_constants.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/utils/http_overrides_helper.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupHttpOverrides();
  ScrollReveal.configureWebScrollInterval();

  try {
    final savedUrl = await SecureStorageService().getServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      ApiConstants.setBaseUrl(savedUrl);
    }
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: SmartPantryApp(),
    ),
  );
}
