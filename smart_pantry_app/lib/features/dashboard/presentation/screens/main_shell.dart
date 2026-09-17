import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/features/admin/presentation/screens/user_management_screen.dart';
import 'package:smart_pantry_app/features/auth/data/models/user_model.dart';
import 'package:smart_pantry_app/features/auth/providers/auth_provider.dart';
import 'package:smart_pantry_app/features/inventory/providers/inventory_provider.dart';
import 'package:smart_pantry_app/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:smart_pantry_app/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:smart_pantry_app/features/inventory/presentation/screens/inventory_list_screen.dart';
import 'package:smart_pantry_app/features/inventory/presentation/screens/office_expense_screen.dart';
import 'package:smart_pantry_app/features/inventory/presentation/screens/pdf_reports_archive_screen.dart';
import 'package:smart_pantry_app/features/shopping_list/presentation/screens/shopping_list_screen.dart';
import 'package:smart_pantry_app/core/services/socket_service.dart';
import 'package:smart_pantry_app/core/responsive/responsive.dart';

final activeNavTabProvider = StateProvider<int>((ref) => 0);

class _NavItemConfig {
  final String key;
  final String title;
  final String shortTitle;
  final IconData icon;
  final Widget screen;
  final int? Function(WidgetRef ref)? badgeCount;
  final Color? badgeColor;

  const _NavItemConfig({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.screen,
    this.badgeCount,
    this.badgeColor,
  });
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshProfile();
      ref.read(socketServiceProvider).init();
    });
  }

  List<_NavItemConfig> _getAllNavConfigs() {
    return [
      _NavItemConfig(
        key: 'dashboard',
        title: 'Dashboard',
        shortTitle: 'Home',
        icon: Icons.dashboard_rounded,
        screen: const HomeDashboardScreen(),
        badgeCount: (ref) {
          final items = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
          final c = items.where((e) => (e.daysLeft ?? 99) <= 2).length;
          return c > 0 ? c : null;
        },
        badgeColor: AppColors.error,
      ),
      _NavItemConfig(
        key: 'pantry',
        title: 'My Pantry',
        shortTitle: 'Pantry',
        icon: Icons.inventory_2_rounded,
        screen: const InventoryListScreen(),
        badgeCount: (ref) {
          final items = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
          return items.isNotEmpty ? items.length : null;
        },
        badgeColor: AppColors.primary,
      ),
      _NavItemConfig(
        key: 'expenses',
        title: 'Expense Detail',
        shortTitle: 'Expenses',
        icon: Icons.receipt_long_rounded,
        screen: const OfficeExpenseScreen(),
        badgeCount: (ref) {
          final items = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
          final c = items.where((e) => e.shoppingNeededQty > 0).length;
          return c > 0 ? c : null;
        },
        badgeColor: const Color(0xFFF59E0B),
      ),
      _NavItemConfig(
        key: 'reports',
        title: 'Saved PDF Reports',
        shortTitle: 'Reports',
        icon: Icons.picture_as_pdf_rounded,
        screen: const PdfReportsArchiveScreen(),
        badgeCount: (ref) {
          final archives = ref.watch(monthlyArchivesProvider).valueOrNull ?? [];
          return archives.isNotEmpty ? archives.length : null;
        },
        badgeColor: const Color(0xFFE11D48),
      ),
      _NavItemConfig(
        key: 'shopping_list',
        title: 'Shopping List',
        shortTitle: 'Shopping',
        icon: Icons.shopping_cart_rounded,
        screen: const ShoppingListScreen(),
        badgeCount: (ref) {
          final items = ref.watch(shoppingListControllerProvider).valueOrNull ?? [];
          final c = items.where((e) => !e.resolved).length;
          return c > 0 ? c : null;
        },
        badgeColor: AppColors.secondary,
      ),
      const _NavItemConfig(
        key: 'users',
        title: 'User Management',
        shortTitle: 'Users',
        icon: Icons.manage_accounts_rounded,
        screen: UserManagementScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(authControllerProvider);
    final currentUser = currentUserAsync.valueOrNull;

    // Show clean loading screen on reload until user permissions and profile are resolved
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Smart Pantry...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isWideScreen = !context.isMobile;
    final isAdmin = currentUser.isAdmin;
    final allConfigs = _getAllNavConfigs();

    // Dynamically filter sections strictly according to user permissions
    final allowedNavItems = allConfigs.where((config) {
      if (config.key == 'users') {
        return isAdmin;
      }
      return currentUser.hasAccess(config.key);
    }).toList();

    // Fallback if empty
    final safeNavItems = allowedNavItems.isEmpty ? [allConfigs.first] : allowedNavItems;

    int currentTab = ref.watch(activeNavTabProvider);
    if (currentTab >= safeNavItems.length) {
      currentTab = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(activeNavTabProvider.notifier).state = 0;
        }
      });
    }

    _visitedTabs.add(currentTab);
    final liveAlert = ref.watch(activeLiveAlertProvider);

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            // Modern Web / Desktop Sidebar
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // App Brand Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.kitchen_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Smart Pantry',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              isAdmin ? 'Admin Portal' : 'Staff Portal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isAdmin
                                    ? AppColors.primaryDark
                                    : const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 16),

                  // Dynamic Navigation Items
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: safeNavItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final item = safeNavItems[i];
                        final isSelected = currentTab == i;
                        final count = item.badgeCount != null ? item.badgeCount!(ref) : null;

                        return _SidebarNavItem(
                          icon: item.icon,
                          title: item.title,
                          isSelected: isSelected,
                          badgeCount: count,
                          badgeColor: item.badgeColor,
                          onTap: () {
                            ref.read(activeNavTabProvider.notifier).state = i;
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Profile / Quick Info Card with Logout
                  Container(
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isAdmin
                              ? AppColors.primaryLight
                              : const Color(0xFF8B5CF6).withOpacity(0.15),
                          child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person_rounded,
                            color: isAdmin
                                ? AppColors.primaryDark
                                : const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentUser.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                isAdmin ? 'Admin' : 'Restricted Access',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isAdmin
                                      ? AppColors.primaryDark
                                      : const Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildProfilePopupMenu(context, currentUser, isAdmin),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area (IndexedStack for filtered allowed screens)
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: currentTab,
                    children: List.generate(
                      safeNavItems.length,
                      (i) => _visitedTabs.contains(i)
                          ? safeNavItems[i].screen
                          : const SizedBox.shrink(),
                    ),
                  ),
                  if (liveAlert != null)
                    Positioned(
                      top: 16,
                      right: 24,
                      child: _buildFloatingAlertNotification(liveAlert, isWideScreen, safeNavItems),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout with Dynamic Navigation Bar
      return Scaffold(
        appBar: AppBar(
          title: Text(safeNavItems[currentTab].title),
          actions: [
            _buildProfilePopupMenu(context, currentUser, isAdmin),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: currentTab,
              children: List.generate(
                safeNavItems.length,
                (i) => _visitedTabs.contains(i)
                    ? safeNavItems[i].screen
                    : const SizedBox.shrink(),
              ),
            ),
            if (liveAlert != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildFloatingAlertNotification(liveAlert, isWideScreen, safeNavItems),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                letterSpacing: -0.2,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentTab,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            backgroundColor: Colors.white,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            onDestinationSelected: (index) {
              ref.read(activeNavTabProvider.notifier).state = index;
            },
            destinations: safeNavItems.map((item) {
              final count = item.badgeCount != null ? item.badgeCount!(ref) : null;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: count != null && count > 0,
                  backgroundColor: item.badgeColor ?? AppColors.primary,
                  label: Text(
                    '$count',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  child: Icon(item.icon),
                ),
                selectedIcon: Icon(item.icon),
                label: item.shortTitle,
              );
            }).toList(),
          ),
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text(
              'Logout Confirmation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Kya aap waqai Smart Pantry se logout karna chahte hain?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel (Wapas)', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  String _getSectionLabel(String key) {
    switch (key) {
      case 'dashboard':
        return 'Dashboard';
      case 'pantry':
        return 'My Pantry';
      case 'expenses':
        return 'Expense Detail';
      case 'reports':
        return 'Saved PDF Reports';
      case 'shopping_list':
        return 'Shopping List';
      case 'users':
        return 'User Management';
      default:
        return key;
    }
  }

  Color _getSectionColor(String key) {
    switch (key) {
      case 'dashboard':
        return const Color(0xFF3B82F6);
      case 'pantry':
        return const Color(0xFF10B981);
      case 'expenses':
        return const Color(0xFFF59E0B);
      case 'reports':
        return const Color(0xFFE11D48);
      case 'shopping_list':
        return const Color(0xFF8B5CF6);
      case 'users':
        return const Color(0xFF0EA5E9);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildProfilePopupMenu(BuildContext context, UserModel currentUser, bool isAdmin) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: Colors.white,
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          elevation: 10,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.menu_rounded,
          size: 26,
          color: AppColors.textPrimary,
        ),
        tooltip: 'Menu & Profile',
        offset: const Offset(0, 48),
        elevation: 10,
        color: Colors.white,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 290,
          maxWidth: 320,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        onSelected: (value) async {
          if (value == 'logout') {
            await _confirmLogout(context);
          } else if (value == 'refresh') {
            await ref.read(authControllerProvider.notifier).refreshProfile();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile & permissions refreshed!'),
                  backgroundColor: AppColors.primaryDark,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Avatar & User Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isAdmin
                          ? AppColors.primaryLight
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded,
                        color: isAdmin
                            ? AppColors.primaryDark
                            : const Color(0xFF8B5CF6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentUser.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentUser.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Role & Permission Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? AppColors.primaryLight : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isAdmin ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                        ),
                      ),
                      child: Text(
                        isAdmin ? 'ADMIN' : 'RESTRICTED USER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isAdmin ? AppColors.primaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isAdmin || currentUser.accessMode == 'can_edit')
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isAdmin || currentUser.accessMode == 'can_edit')
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (isAdmin || currentUser.accessMode == 'can_edit')
                                ? Icons.edit_note_rounded
                                : Icons.visibility_rounded,
                            size: 11,
                            color: (isAdmin || currentUser.accessMode == 'can_edit')
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isAdmin
                                ? 'Full Edit Access'
                                : currentUser.accessMode == 'can_edit'
                                    ? 'Can Edit'
                                    : 'Just View (Sirf Dekh Saky)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: (isAdmin || currentUser.accessMode == 'can_edit')
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 8),

                // Accessible Sections
                Text(
                  'Accessible Sections (${currentUser.allowedSections.length}):',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: currentUser.allowedSections.map((secKey) {
                    final label = _getSectionLabel(secKey);
                    final color = _getSectionColor(secKey);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<String>(
            value: 'refresh',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.sync_rounded, size: 18, color: AppColors.primaryDark),
                SizedBox(width: 10),
                Text(
                  'Refresh Profile & Permissions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'logout',
            height: 46,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Logout (Sign Out)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAlertNotification(
    LiveUsageAlert alert,
    bool isWideScreen,
    List<_NavItemConfig> safeNavItems,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isWideScreen ? 420 : double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6366F1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE ENTRY 🔔',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert.staffName,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Day ${alert.dayOfMonth}: ${alert.ingredientName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () {
                    ref.read(socketServiceProvider).dismissAlert();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quantity: ${alert.amount.toStringAsFixed(alert.amount.truncateToDouble() == alert.amount ? 0 : 2)} ${alert.unit} (Staff ke liye locked hai)',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(socketServiceProvider).dismissAlert();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(socketServiceProvider).dismissAlert();
                    final expenseIdx = safeNavItems.indexWhere((e) => e.key == 'expenses');
                    if (expenseIdx != -1) {
                      ref.read(activeNavTabProvider.notifier).state = expenseIdx;
                    }
                  },
                  icon: const Icon(Icons.table_chart_rounded, size: 14),
                  label: const Text('Sheet Me Dekhein', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final int? badgeCount;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    this.badgeCount,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeCount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? (badgeColor ?? AppColors.primary) : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
