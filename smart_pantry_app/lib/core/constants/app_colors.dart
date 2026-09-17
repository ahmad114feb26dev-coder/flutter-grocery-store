import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF10B981); // Vibrant Emerald Green
  static const Color primaryDark = Color(0xFF047857);
  static const Color primaryLight = Color(0xFFD1FAE5);
  
  static const Color secondary = Color(0xFFF59E0B); // Amber Warmth
  static const Color secondaryLight = Color(0xFFFEF3C7);
  
  static const Color accent = Color(0xFF6366F1); // Indigo Accent
  static const Color accentLight = Color(0xFFEEF2FF);
  
  static const Color background = Color(0xFFF8FAFC); // Clean Slate tint
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  
  // Status colors
  static const Color error = Color(0xFFEF4444); // Expired / Urgent Red
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B); // Expiring Soon Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color success = Color(0xFF10B981); // Fresh Safe Green
  static const Color successLight = Color(0xFFD1FAE5);
  
  // Text colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  
  // Borders and Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Category specific accent colors
  static Color getCategoryBg(String category) {
    switch (category.toLowerCase()) {
      case 'produce':
      case 'vegetables':
      case 'fruits':
        return const Color(0xFFECFDF5);
      case 'dairy':
      case 'milk':
      case 'cheese':
        return const Color(0xFFEFF6FF);
      case 'meat':
      case 'poultry':
      case 'seafood':
        return const Color(0xFFFFF1F2);
      case 'bakery':
      case 'bread':
        return const Color(0xFFFFFBEB);
      case 'pantry':
      case 'grains':
      case 'canned':
        return const Color(0xFFFAF5FF);
      case 'spices':
      case 'condiments':
        return const Color(0xFFF0FDFA);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'produce':
      case 'vegetables':
      case 'fruits':
        return const Color(0xFF059669);
      case 'dairy':
      case 'milk':
      case 'cheese':
        return const Color(0xFF2563EB);
      case 'meat':
      case 'poultry':
      case 'seafood':
        return const Color(0xFFE11D48);
      case 'bakery':
      case 'bread':
        return const Color(0xFFD97706);
      case 'pantry':
      case 'grains':
      case 'canned':
        return const Color(0xFF7C3AED);
      case 'spices':
      case 'condiments':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF475569);
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'produce':
      case 'vegetables':
      case 'fruits':
        return Icons.eco_rounded;
      case 'dairy':
      case 'milk':
      case 'cheese':
        return Icons.water_drop_rounded;
      case 'meat':
      case 'poultry':
      case 'seafood':
        return Icons.kebab_dining_rounded;
      case 'bakery':
      case 'bread':
        return Icons.bakery_dining_rounded;
      case 'pantry':
      case 'grains':
      case 'canned':
        return Icons.inventory_2_rounded;
      case 'spices':
      case 'condiments':
        return Icons.soup_kitchen_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }
}
