import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/animations/scroll_reveal.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ScrollReveal.configureWebScrollInterval();

  runApp(
    const ProviderScope(
      child: SmartPantryApp(),
    ),
  );
}
